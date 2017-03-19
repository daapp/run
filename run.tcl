#! /bin/sh
# \
exec tclsh "$0" ${1+"$@"}

package require Tk

# Maximum size of history file
set history_size 20

#list of hosts, which you use to connect via rsh (look into you .rhosts)
set hostlist {rhine mod env amazon}

# do various program require xterm
array set xterm {
    grep 1
    sed 1
    netscape* 0
    awk 1
    tar 1
    mc 1
}


proc layout {} {
    global hostlist host
    frame .input
    label .input.l -text "Command: "
    entry .input.e -background white -textvariable command -exportselection false
    menubutton .input.history -pady 0 -text V -menu .input.history.m -relief raised
    menu .input.history.m
    readhistory .input.history.m
    pack .input.l .input.e .input.history -side left -fill y
    pack .input.e -fill x -expand true

    frame .buttons

    frame .buttons.w
    label .buttons.w.l -text "Host: " -anchor w
    eval tk_optionMenu .buttons.w.m host localhost $hostlist
    pack .buttons.w.l .buttons.w.m -side left

    frame .buttons.s1 -padx 5

    button .buttons.run -text Run -command run
    button .buttons.cancel -text Cancel -command quit
    button .buttons.browse -text Browse... -command browse
    grid .buttons.w .buttons.s1 .buttons.run .buttons.cancel .buttons.browse -sticky ew -pady 5 -pady 5
    grid columnconfigure .buttons {1 2 3} -uniform a

    pack .input -fill x -expand true -padx 5 -pady 5
    pack .buttons -fill x -padx 5 -pady 0 -expand true

    bind . <Escape> quit
    bind .input.e <Key-Return> [list .buttons.run invoke]
    bind . <Map> {wm geometry . [winfo reqwidth .]x[winfo reqheight .]}

    wm title . Run
    wm positionfrom . program
    wm resizable . 0 0

    tk app Run
    focus -force .input.e
}


proc quit {} {
    exit 0
}

#
# Pops up standard file selection dialog and inserts selected file into
# command line. Note - not only as command, but as argument as well
#
proc browse {} {
    set name [tk_getOpenFile ]
    if {"$name"==""} return
    if [.i.e selection present] {
        .i.e delete sel.first sel.last
        .i.e insert sel.first $name
    } else {
        .i.e insert insert $name
    }
}

#
# Runs desired command and records it in the history file
#
proc run {} {
    global command term host
    if {"$host"=="localhost" } {
        exec /bin/sh -c $command >/dev/$term </dev/$term 2>/dev/$term &
    } else {
        exec rsh $host $command >/dev/$term </dev/$term 2>/dev/$term &
    }
    set f [open ~/.run_history a+]
    puts $f $command
    close $f
    destroy .
}

#
# Reads history file. If it is too long, deletes first few items and rewrites
# file. Inserts commands from history file in given menu
#
proc readhistory {menu} {
    global history_size
    if [catch {open ~/.run_history} f] {
        $menu add command -label xterm -command "set command xterm"
    } else {
        set list {}
        while {![eof $f]} {
            set entry [gets $f]
            if {![string length $entry]} continue
            set list [linsert $list 0 $entry]
        }
        close $f
        if {[llength $list]>$history_size} {
            set list [lreplace $list $history_size end]
            set f [open ~/.run_history w]
            for {set i [expr $history_size-1]} {$i>=0} {incr i -1} {
                puts $f [lindex $list $i]
            }
            close $f
        }
        foreach entry $list {
            $menu add command -label $entry -command [list set command $entry]
        }
    }
}

set term stdout
layout
