
source tfast.tcl
source http/backend/pure.tcl
#source http/backend/easybeast.tcl

namespace import ::tfast::*

proc index {req} {
    render -text {hello, tfast!!}
}

proc cors {req resp} {
    set origin [$req header Origin]

    if {$origin != ""} {
	$resp header Access-Control-Allow-Origin $origin
	$resp header Access-Control-Allow-Methods *
	$resp header Access-Control-Allow-Headers *
	$resp header Access-Control-Max-Age [expr {60*60*24*365}]
    }

    return $resp
}

#tfast ns / -leave ::cors

tfast options,head * {req {
    puts "::> options"
    render
}}

# simple route
tfast get /lambda {req {
    render -text {hello, tfast!!}
}}

tfast get /proc ::index

tfast register public dir ./tests
tfast register public extension .js,.jpg
tfast register filter proc myfilter
tfast register filter object myobject

tfast print -all

#tfast serve -port 3000 -host 0.0.0.0 ; #-backend easybeast
