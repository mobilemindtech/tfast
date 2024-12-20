# TCL http server


```tcl

package require tfast


namespace import ::tfast::*
namespace import ::tfast::http::backend::pure

proc index {req} {
    render -text {hello, tfast!!}
}

# simple route
tfast get /lambda {req {
    render -text {hello, tfast!!}
}}

tfast get /proc ::index

tfast serve -port 3000 -host 0.0.0.0

```
