
source tfast.tcl
source http/backend/http_pure.tcl

namespace import ::tfast::*

proc index {req} {
    render -text {hello, tfast!!}
}

# simple route
tfast get /lambda {req {
    render -text {hello, tfast!!}
}}

tfast get /proc ::index

tfast serve -port 3000 -host 0.0.0.0
