#! /bin/sh
# \
exec tclsh "$0" ${1+"$@"}

# (c) 2017 Alexander Danilov <alexander.a.danilov@gmail.com>
# tcllib (fileutil package) required to run this application.

package require Tk
package require Ttk

# Maximum size of history file
set history_size 20

# Maximum menu size
set completionMenuSize 30

#list of hosts, which you use to connect via rsh (look into you .rhosts)
set hostlist {nas}
set term stdout

set command ""

# xterm command for ssh prefix
set xterm "xterm -e"

proc main {} {
    global hostlist host

    ttk::label .l1 -text "Command:"
    ttk::entry .command \
               -textvariable command \
               -exportselection false
    button .browse \
                -text ... \
                -underline 0 \
                -command [list browse .command]
    
    ttk::label .l2 -text "Host:"
    eval tk_optionMenu .hostMenu host localhost $hostlist

    ttk::separator .s1 -orient horizontal

    ttk::button .run \
                -text Run \
                -underline 0 \
                -command [list run]

    grid .l1 .command .browse -sticky e -padx 5 -pady 2
    grid .l2 .hostMenu x -sticky e -padx 5 -pady 2
    grid .s1 - - -sticky ew -padx 5 -pady 5
    grid x .run - -sticky e -padx 5 -pady 5
    grid columnconfigure . .command -weight 2
    grid anchor .run e

    menu .historyMenu -tearoff 0
    menu .completionMenu -tearoff 0
    readhistory .historyMenu


    bind . <Escape> quit
    bind .command <Tab> [list completion .completionMenu .command]
    bind .command <Key-Return> run
    bind .command <Key-Down> {
        if {$command ne ""} {
            .completionMenu activate 0
            after idle focus .completionMenu
        } else {
            .historyMenu post [winfo rootx .command] [expr {[winfo rooty .command] + [winfo height .command]}]
            after idle focus .historyMenu
        }
    }
    bind .historyMenu <Unmap> {
        after idle {
            focus -force .command
            .command icursor end
        }
    }
    bind .completionMenu <Escape> {
        %W unpost
        after idle {focus -force .command}
    }
    bind .completionMenu <Unmap> {
        after idle {
            focus -force .command
            .command icursor end
        }
    }
    bind . <Map> {wm geometry . [winfo reqwidth .]x[winfo reqheight .]}
    bind . <Alt-b> [list .browse invoke]
    bind . <Alt-r> run
    bind . <Alt-h> {
        .hostMenu.menu post [winfo rootx .hostMenu] [expr {[winfo rooty .hostMenu] + [winfo height .hostMenu]}]
        after idle focus .hostMenu.menu
    }
    bind .hostMenu.menu <Unmap> {
        after idle {
            focus -force .command
        }
    }

    wm title . Run
    wm positionfrom . program
    wm resizable . 0 0

    tk app Run
    focus -force .command
}


proc quit {} {
    destroy .
    exit 0
}

#
# Pops up standard file selection dialog and inserts selected file into
# command line. Note - not only as command, but as argument as well
#
proc browse {command} {
    set name [tk_getOpenFile ]
    if {"$name" == ""} return

    if [$command selection present] {
        $command delete sel.first sel.last
        $command insert sel.first $name
    } else {
        $command insert insert $name
    }
    focus $command
    $command xview end 
}

#
# Runs desired command and records it in the history file
#
proc run {} {
    global command term host xterm

    set command [string trim $command]
    if {[string match "ssh *" $command]} {
        exec {*}$xterm "auto$command" &
    } elseif {"$host" eq "localhost" } {
        exec /bin/sh -c $command >/dev/$term </dev/$term 2>/dev/$term &
    } else {
        exec rsh -X $host $command >/dev/$term </dev/$term 2>/dev/$term &
    }
    set f [open ~/.run_history a+]
    puts $f $command
    close $f
    quit
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


proc completion {menuName command} {
    set text [$command get]
    if {[string length $text] >= 3} {
        $menuName delete 0 end
        package require fileutil
        set found [list]
        foreach path [split $::env(PATH) :] {
            foreach file [fileutil::findByPattern $path -glob $text*] {
                lappend found [lindex [file split $file] end]
            }
        }
        if {[llength $found] > 0} {
            if {[llength $found] == 1} {
                set ::command [lindex $found 0]
                $command icursor end
            } else {
                foreach file [lrange $found 0 [expr {$::completionMenuSize - 1}]] {
                    $menuName add command -label $file -command [list set command $file]
                }
                if {[llength $found] > $::completionMenuSize} {
                    $menuName add command -label "[expr {[llength $found] - $::completionMenuSizey}] command(s) hidden ..."
                }
                $menuName post [winfo rootx $command] [expr {[winfo rooty $command] + [winfo height $command]}]
                $menuName activate 0
                after idle focus $menuName
            }
        }
    }
    # stop focus to next widget
    return -code break
}

main
