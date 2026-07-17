source tfast.tcl
#source http/backend/pure.tcl
source http/backend/easybeast.tcl

namespace import ::tfast::*

proc index {req} {
  render -text {hello, tfast!!}
}

set cors [::tfast::http::middleware::cors origin * methods * headers * max-age 3600]

tfast ns * \
  -method options,head \
  -enter $cors

#tfast options,head * {req {
#    puts "::> options"
#    render
#}}

# simple route
tfast get /lambda {req {
    render -text {hello, tfast!!}
}}

tfast get /proc ::index

tfast print -routes
# tfast help
tfast serve -port 3000 -host 0.0.0.0 -backend easybeast