//! Standalone Rust replica of scripts/mullet.just — an experiment in
//! porting the imperative-package escape hatch to a portable binary.
//! Not invoked by mullet.just and does not invoke it; the two
//! implementations exist side by side and mullet.just is unmodified.

mod mullet;

use std::env;
use std::io::{self, BufRead, Write};
use std::path::PathBuf;
use std::process::{exit, Command};

use clap::{Parser, Subcommand};
use mullet::{mullet_add_line, mullet_contains, mullet_rm_line};

const SEARCH_FALLBACK_LINES: usize = 15;
const ADD_FALLBACK_LINES: usize = 10;

#[derive(Parser)]
#[command(
    name = "mullet",
    about = "Imperative package escape hatch (Rust replica of mullet.just)"
)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Search Nix-Index for a binary, falling back to nixpkgs descriptions
    Search { query: String },
    /// Validate and add a package to the Mullet
    Add { pkg: String },
    /// Remove a package from the Mullet
    Rm { pkg: String },
    /// List packages currently in the Mullet
    Lst,
    /// Remove all imperative packages (with confirmation)
    Haircut,
}

fn mullet_file() -> PathBuf {
    let user = env::var("USER").unwrap_or_else(|_| {
        eprintln!(":: Error: USER environment variable is not set. ::");
        exit(1);
    });
    PathBuf::from(format!("users/{user}/var/mullet.txt"))
}

fn run_capture(argv: &[&str]) -> (bool, String) {
    match Command::new(argv[0]).args(&argv[1..]).output() {
        Ok(output) => (
            output.status.success(),
            String::from_utf8_lossy(&output.stdout).into_owned(),
        ),
        Err(_) => (false, String::new()),
    }
}

fn nix_locate(query: &str) -> String {
    let target = format!("/bin/{query}");
    let (_, out) = run_capture(&[
        "nix-locate",
        "--top-level",
        "--minimal",
        "--at-root",
        &target,
    ]);
    out
}

fn nix_search_head(query: &str, n: usize) -> String {
    let (_, out) = run_capture(&["nix", "search", "nixpkgs", query]);
    out.lines().take(n).collect::<Vec<_>>().join("\n")
}

fn cmd_search(query: &str) {
    println!(":: Searching Nix-Index for binary '{query}' ::");
    let results = nix_locate(query);
    if !results.trim().is_empty() {
        print!("{results}");
        if !results.ends_with('\n') {
            println!();
        }
        return;
    }
    println!(":: No exact binary match in Nix-Index. ::");
    println!(":: Searching Nixpkgs descriptions... ::");
    println!("{}", nix_search_head(query, SEARCH_FALLBACK_LINES));
}

fn cmd_add(pkg: &str) {
    let file = mullet_file();
    match mullet_contains(&file, pkg) {
        Ok(true) => {
            println!(":: '{pkg}' is already in The Mullet. ::");
            return;
        }
        Ok(false) => {}
        Err(err) => {
            eprintln!(":: Error: failed to read The Mullet: {err} ::");
            exit(1);
        }
    }

    println!(":: Verifying '{pkg}' exists... ::");
    let (ok, _) = run_capture(&[
        "nix",
        "eval",
        &format!("nixpkgs#{pkg}"),
        "--apply",
        "p: p.outPath or p.pname or p.name",
    ]);
    if !ok {
        println!(":: Error: '{pkg}' is not a valid package path. ::");
        println!(":: Did you mean one of these? (Searching Nix-Index for '{pkg}') ::");
        println!();
        print!("{}", nix_locate(pkg));
        println!();
        println!(":: (Fallback) Searching Nixpkgs descriptions... ::");
        println!("{}", nix_search_head(pkg, ADD_FALLBACK_LINES));
        exit(1);
    }

    if let Err(err) = mullet_add_line(&file, pkg) {
        eprintln!(":: Error: failed to add '{pkg}' to The Mullet: {err} ::");
        exit(1);
    }
    println!(":: Added {pkg}. Run 'ft switch' to apply. ::");
}

fn cmd_rm(pkg: &str) {
    let file = mullet_file();
    match mullet_contains(&file, pkg) {
        Ok(true) => {}
        Ok(false) => {
            eprintln!(":: Error: '{pkg}' not found in The Mullet. ::");
            exit(1);
        }
        Err(err) => {
            eprintln!(":: Error: failed to read The Mullet: {err} ::");
            exit(1);
        }
    }
    if let Err(err) = mullet_rm_line(&file, pkg) {
        eprintln!(":: Error: failed to remove '{pkg}' from The Mullet: {err} ::");
        exit(1);
    }
    println!(":: Removed {pkg}. Run 'ft switch' to apply. ::");
}

fn cmd_lst() {
    println!(":: Imperative Packages (The Mullet) ::");
    match std::fs::read_to_string(mullet_file()) {
        Ok(contents) => print!("{contents}"),
        Err(_) => println!("  (Empty)"),
    }
}

fn cmd_haircut() {
    print!("This removes all imperative packages. Continue? [y/N]: ");
    io::stdout().flush().ok();
    let mut input = String::new();
    io::stdin().lock().read_line(&mut input).ok();
    if matches!(input.trim(), "y" | "Y") {
        if let Err(err) = std::fs::write(mullet_file(), "") {
            eprintln!(":: Error: failed to clear The Mullet: {err} ::");
            exit(1);
        }
        println!(":: Haircut complete. Run 'ft switch' to apply the clean slate. ::");
    } else {
        println!("Cancelled.");
    }
}

fn main() {
    match Cli::parse().command {
        Commands::Search { query } => cmd_search(&query),
        Commands::Add { pkg } => cmd_add(&pkg),
        Commands::Rm { pkg } => cmd_rm(&pkg),
        Commands::Lst => cmd_lst(),
        Commands::Haircut => cmd_haircut(),
    }
}
