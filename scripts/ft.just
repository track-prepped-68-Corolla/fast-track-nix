set quiet := true

import "./sys.just"
import "./bootstrap.just"
import "./mullet.just"
import "./store.just"
import "./drives.just"
import "./failover.just"
import "./fleet.just"
import "./komodo.just"

default:
    just --list

alias r  := switch
alias t  := test
alias c  := check
alias cl := clean
alias s  := sync
