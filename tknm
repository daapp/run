#! /bin/sh
# -*- mode: Tcl; -*- \
exec tclsh "$0" ${1+"$@"}

# connection manager using nmcli as backend

package require Tk
package require Ttk
package require msgcat
package require widget::scrolledwindow

namespace import msgcat::mc msgcat::mcset


set program "Network manager"
set version 0.3
set title "$program $version"

set maxLogLines 10

array set typeMap {
    802-11-wireless wifi
    802-3-ethernet  eth
    bluetooth       bt
    loopback        lo
}

set confFile [file join $env(HOME) .[file tail $argv0].conf]
array set conf {}

namespace eval conf {
    proc load {fileName} {
        set r {}
        if {[catch {
            set f [open $fileName r]
            set r [dict create {*}[read $f]]
            close $f
        } errorMessage]} {
            puts stderr $errorMessage
            return {}
        } else {
            return $r
        }
    }

    # newConf - is a dict
    proc save {fileName newConf} {
        set f [open $fileName w]
        dict for {k v} $newConf {
            puts $f "$k $v"
        }
        close $f
    }
}


namespace eval nm {
    # path to network-manager CLI
    variable nmcli "nmcli"
    variable monitorChannel ""

    proc nmcli {args} {
        variable nmcli

        exec $nmcli {*}$args
    }


    proc connections {} {
        variable nmcli

        set conns [list]
        foreach l [split [nmcli --colors=no -t -e yes -f name,active,type,uuid c] \n] {
            lassign [split $l :] name active type uuid
            lappend conns [list name $name active $active type $type uuid $uuid]
        }
        return $conns
    }


    # command should accept 1 argument - file handle
    proc monitor {{command ""}} {
        variable nmcli
        variable monitorChannel

        if {$command ne ""} {
            set monitorChannel [open "| $nmcli c monitor" r]
            chan configure $monitorChannel -blocking 0 -buffering line
            chan event $monitorChannel readable [list $command $monitorChannel]
        } else {

            if {[catch {exec kill [pid $monitorChannel]} e]} {
                puts stderr $e
            }
            chan close $monitorChannel
        }
    }
}


array set w {}
set conns [dict create]

proc main {args} {
    variable w
    variable conf
    variable confFile

    array set conf [conf::load $confFile]

    set title [ttk::frame .title]
    ttk::label $title.text -text "$::program $::version" -anchor center
    pack $title.text -side top -fill x -padx 10 -pady 10 -anchor center

    set sl [widget::scrolledwindow .sl -scrollbar vertical]
    set w(networks) [listbox $sl. -font TkFixedFont]
    $sl setwidget $w(networks)

    set w(types) [ttk::frame .types -relief raised]

    set sw [widget::scrolledwindow .sw -scrollbar vertical]
    set w(log) [text $sw.nmLog -wrap word -height 5 -width 40]
    $sw setwidget $w(log)
    set font [expr {[dict get [font actual [$w(log) cget -font]] -size] * 2 / 3}]
    $w(log) configure -font [list -size $font]

    set buttons [ttk::frame .buttons]
    ttk::button $buttons.exit -text [mc "Exit"] -command quit
    pack $buttons.exit -side right

    pack $title -side top -fill x
    pack $w(types) -side top -fill x -padx 10 -pady 10
    pack $sl -side top -fill both -expand true -padx 10 -pady 10
    pack $buttons -side bottom -fill x -padx 10 -pady 10
    pack $sw -side bottom -fill x -padx 10 -pady 10

    after idle showConnections

    bind $w(networks) <Return> toggleNetwork
    bind $w(networks) <Double-Button-1> toggleNetwork
    bind $w(networks) <Home> [bind Listbox <Control-Home>]
    bind $w(networks) <End> [bind Listbox <Control-End>]

    bind . <Map> [list apply {{} {
        global w
        set rw [winfo reqwidth .]
        set rh [winfo reqheight .]
        if {$rw > $rh} {
            set rh [expr {int($rw / 1.33)}]
        } else {
            set rw [expr {int($rh / 1.33)}]
        }

        wm geometry . ${rw}x${rh}
        focus $w(networks)
    }}]

    bind . <Control-q> quit
    bind . <Escape> quit

    wm title . $::title
    wm positionfrom . program
    wm resizable . 0 0

    after idle nm::monitor updateConnections

}


proc showConnections {} {
    variable w
    variable conns
    variable typeMap
    variable conf

    set index [$w(networks) index active]
    $w(networks) delete 0 end
    set conns [nm::connections]
    set nameWidth [lmap c $conns {string length [dict get $c name]}]

    set types {}
    foreach conn $conns {
        if {[info exists typeMap([dict get $conn type])]} {
            set type $typeMap([dict get $conn type])
        } else {
            set type [dict get $conn type]
        }

        lappend types $type

        if {![info exists conf($type)]} {
            set conf($type) show
        }

        if {$conf($type) ne "hide"} {
            $w(networks) insert end [format "%4s / %s" $type [dict get $conn name]]
            set color [expr {[dict get $conn active] eq "yes" ? "green" : "red"}]
            $w(networks) itemconfigure end -foreground $color -selectforeground $color
        }
    }

    # hide unexistent types
    foreach cb [winfo children $w(types)] {
        if {[lindex [split $cb .] end] in $types} {
            pack $cb
        } else {
            pack forget $cb
        }
    }
    foreach t [lsort $types] {
        if {[winfo exists $w(types).$t]} {

        } else {
            ttk::checkbutton $w(types).$t \
                -offvalue hide \
                -onvalue show \
                -style Toolbutton \
                -variable conf($t) \
                -command {after idle showConnections} \
                -text $t
            pack $w(types).$t -side left -padx 5 -pady 5
        }
    }

    $w(networks) activate $index
    $w(networks) selection anchor $index
    $w(networks) selection set $index
}


proc updateConnections {channel} {
    variable w

    gets $channel s
    log $s

    showConnections
}


proc log {s} {
    variable w
    variable maxLogLines

    $w(log) insert end $s\n
    $w(log) see end

    set index [$w(log) index end]
    set max ${maxLogLines}.0
    if {$index > $maxLogLines} {
        $w(log) delete 0.0 [expr {$index - $max}]
    }
}


proc toggleNetwork {} {
    variable conns
    variable w

    set connName [lindex [split [$w(networks) get [$w(networks) curselection]] " / "] end]

    set active ""
    set uuid ""
    foreach c $conns {
        if {[dict get $c name] eq $connName} {
            set active [dict get $c active]
            set uuid [dict get $c uuid]
            break
        }
    }
    set command [expr {$active eq "yes" ? "down" : "up"}]

    log [nm::nmcli c $command $uuid]
    showConnections
}


proc quit {} {
    variable conf
    variable confFile

    conf::save $confFile [array get conf]

    nm::monitor

    exit 0
}


main $argv
