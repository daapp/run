#! /bin/sh
# \
exec tclsh "$0" ${1+"$@"}

package require Tk
package require Ttk
package require msgcat

namespace import msgcat::mc msgcat::mcset


ttk::style configure TButton \
    -background lightblue \
    -foreground black \
    -padding {0 7} \
    -width -4
ttk::style map TButton \
    -background [list active lightblue] \
    -foreground [list disabled black]


set text ""

proc main {args} {
    variable text
    
    set f [ttk::frame .output]

    set text [text $f.text -font TkFixedFont \
                  -xscrollcommand [list $f.sx set] \
                  -yscrollcommand [list $f.sy set]]
    ttk::scrollbar $f.sx -orient horizontal -command [list $f.text xset]
    ttk::scrollbar $f.sy -orient vertical -command [list $f.text yset]

    grid $f.text -sticky nsew
    grid $f.sy -row 0 -column 1 -sticky nsew
    grid $f.sx -row 1 -column 0 -sticky ew
    grid columnconfigure $f 0 -weight 1
    grid rowconfigure $f 0 -weight 1

    pack $f -fill both -expand true -side top


    set f [ttk::frame .statusbar]
    ttk::button $f.exit -text "Esc" -state disabled
    ttk::label $f.exitLabel -text " - [mc exit]"
    pack $f.exit $f.exitLabel -side left -fill x
    
    pack $f -fill x -side bottom -pady 5 -padx 5

    wm title . tkpager

    bind . <Escape> exit
    #bind $text <<Insert>> break

    after idle focus $text

    after 1 prepare
}


proc prepare {} {
    chan configure stdin -buffering line -blocking 0
    chan event stdin readable readData
}


proc readData {} {
    variable text
    gets stdin s
    if {[chan eof stdin]} {
        chan close stdin
    }

    set insert [$text index insert]
    $text insert end $s\n
    $text mark set insert $insert
}


main {*}$argv
