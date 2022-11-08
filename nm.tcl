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
set version 0.1
set title "$program $version"

set maxLogLines 10

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

        set conns [dict create]
        foreach l [split [nmcli --colors=no -t -e yes -f name,active,type c] \n] {
            lassign [split $l :] name active type
            dict set conns $name [list active $active type $type]
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

    set title [ttk::frame .title]
    ttk::label $title.text -text "$::program $::version" -anchor center
    pack $title.text -side top -fill x -padx 10 -pady 10 -anchor center

    set sl [widget::scrolledwindow .sl -scrollbar vertical]
    set w(networks) [listbox $sl. -font TkFixedFont]
    $sl setwidget $w(networks)

    set sw [widget::scrolledwindow .sw -scrollbar vertical]
    set w(log) [text $sw.nmLog -wrap word -height 5 -width 40]
    $sw setwidget $w(log)
    set font [expr {[dict get [font actual [$w(log) cget -font]] -size] * 2 / 3}]
    $w(log) configure -font [list -size $font]

    set buttons [ttk::frame .buttons]
    ttk::button $buttons.exit -text [mc "Exit"] -command quit
    pack $buttons.exit -side right

    pack $title -side top -fill x
    pack $sl -side top -fill both -expand true -padx 10 -pady 10
    pack $buttons -side bottom -fill x -padx 10 -pady 10
    pack $sw -side bottom -fill x -padx 10 -pady 10
    
    after idle showConnections

    bind $w(networks) <Return> toggleNetwork
    bind . <Map> {
        wm geometry . [winfo reqwidth .]x[winfo reqheight .]
        focus $w(networks) 

    }
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

    set index [$w(networks) index active]
    $w(networks) delete 0 end
    set conns [nm::connections]
    foreach name [lsort [dict keys $conns]] {
        $w(networks) insert end "$name / [dict get $conns $name type]"
        $w(networks) itemconfigure end \
            -foreground [expr {[dict get $conns $name active] eq "yes" ? "green" : "red"}]
    }
    $w(networks) activate $index
    $w(networks) selection anchor $index
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

    set name [string trim [lindex [split [$w(networks) get [$w(networks) curselect]] /] 0]]
    
    set command [expr {[dict get $conns $name active] eq "yes" ? "down" : "up"}]

    log [nm::nmcli c $command $name]
    showConnections
}


proc quit {} {
    nm::monitor

    exit 0
}


main $argv
