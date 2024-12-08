
source tfast.tcl

namespace import ::tfast::*

# simple route
tfast get / {req resp {
    render -text {hello, tfast!!}
}}

# middleware -> route -> middleware
tfast post /app {req {}} {req {}} {req resp {}}

#tfast any ...
#tfast get,post ...

# namespace middleware
# -recover catch all errors
# -status 404 catch only 404 and can recover by self
# -method is applied only enter or leave
tfast ns /ap1/v1 \
    -method get,post \
    -enter {req {}} \
    -leave {req resp {}} \
    -recover {req resp {}} \
    -status 404 {req resp {}} \
    -status 500 {req resp {}}

tfast ns /api {

    enter / {
	{req {}}
    }

    leave / {
	{req resp {}}
    }

    recover / { req resp {}}

    404 / {req {}}
    
    get / {req {}}
    
    post / {req {}}

    any / {req {}}

    put,delete {req {}}

    # /api/app
    ns /app {
	get {req {}}
    }
}

tfast serve -port 3000 -host 0.0.0.0
