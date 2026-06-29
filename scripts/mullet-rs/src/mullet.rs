//! Pure file-manipulation helpers mirroring scripts/lib/mullet.sh.
//! Entries are one package attribute per line, optionally surrounded by
//! spaces/tabs — same format as the bash and Python implementations.

use std::fs;
use std::fs::OpenOptions;
use std::io::Write;
use std::path::Path;

fn line_matches(line: &str, pkg: &str) -> bool {
    line.trim_matches(|c: char| c == ' ' || c == '\t') == pkg
}

/// Mirrors mullet_contains() in lib/mullet.sh.
pub fn mullet_contains(file: &Path, pkg: &str) -> std::io::Result<bool> {
    match fs::read_to_string(file) {
        Ok(contents) => Ok(contents.lines().any(|line| line_matches(line, pkg))),
        Err(err) if err.kind() == std::io::ErrorKind::NotFound => Ok(false),
        Err(err) => Err(err),
    }
}

/// Mirrors mullet_add_line() in lib/mullet.sh. Caller is responsible for
/// validation/dedup, same as the bash helper.
pub fn mullet_add_line(file: &Path, pkg: &str) -> std::io::Result<()> {
    if let Some(parent) = file.parent() {
        fs::create_dir_all(parent)?;
    }
    let mut f = OpenOptions::new().create(true).append(true).open(file)?;
    writeln!(f, "{pkg}")
}

/// Mirrors mullet_rm_line() in lib/mullet.sh.
pub fn mullet_rm_line(file: &Path, pkg: &str) -> std::io::Result<()> {
    let contents = match fs::read_to_string(file) {
        Ok(contents) => contents,
        Err(err) if err.kind() == std::io::ErrorKind::NotFound => return Ok(()),
        Err(err) => return Err(err),
    };
    let kept: String = contents
        .lines()
        .filter(|line| !line_matches(line, pkg))
        .map(|line| format!("{line}\n"))
        .collect();
    fs::write(file, kept)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_file(name: &str) -> std::path::PathBuf {
        let mut p = std::env::temp_dir();
        p.push(format!("mullet-test-{}-{name}", std::process::id()));
        p
    }

    #[test]
    fn contains_finds_a_present_package() {
        let f = temp_file("contains-present");
        fs::write(&f, "ripgrep\nfd\n").unwrap();
        assert!(mullet_contains(&f, "ripgrep").unwrap());
    }

    #[test]
    fn contains_rejects_an_absent_package() {
        let f = temp_file("contains-absent");
        fs::write(&f, "ripgrep\nfd\n").unwrap();
        assert!(!mullet_contains(&f, "bat").unwrap());
    }

    #[test]
    fn contains_tolerates_surrounding_whitespace() {
        let f = temp_file("contains-whitespace");
        fs::write(&f, "  ripgrep  \n").unwrap();
        assert!(mullet_contains(&f, "ripgrep").unwrap());
    }

    #[test]
    fn contains_false_when_file_missing() {
        let f = temp_file("contains-missing");
        let _ = fs::remove_file(&f);
        assert!(!mullet_contains(&f, "ripgrep").unwrap());
    }

    #[test]
    fn add_line_appends() {
        let f = temp_file("add-appends");
        fs::write(&f, "fd\n").unwrap();
        mullet_add_line(&f, "bat").unwrap();
        assert_eq!(fs::read_to_string(&f).unwrap(), "fd\nbat\n");
    }

    #[test]
    fn rm_line_removes_only_the_named_package() {
        let f = temp_file("rm-removes");
        fs::write(&f, "fd\nripgrep\nbat\n").unwrap();
        mullet_rm_line(&f, "ripgrep").unwrap();
        assert_eq!(fs::read_to_string(&f).unwrap(), "fd\nbat\n");
    }
}
