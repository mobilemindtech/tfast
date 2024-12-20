
package require uuid
package require coroutine
package require logger

namespace eval ::tfast::http::backend::pure {

    variable log
    variable ServerSocket_fd

    set log [logger::init tfast::http::backend::pure]


    proc serve {host port workers} {

	variable log
	variable ServerSocket_fd

	if {$workers > 1} {
	    worker_init $workers
	    set socket [socket -server worker_accept $port]  
	} else {
	    set socket [socket -server http_accept $port]  
	}

	${log}::info "http server started on http://localhost:$port"

	set ServerSocket_fd $socket

	#websocket_init $socket

	vwait forever	
    }


    proc http_accept {socket addr port} {
	set uuid [uuid::uuid generate]
	coroutine [namespace current]::$uuid [namespace current]::handle $socket $addr $port
	chan configure $socket -blocking 0 -buffering line
	chan event $socket readable [namespace current]::$uuid
	#chan event $socket readable [list ::tfast::http::handle $socket $addr $port]  
    }

    proc handle {socket addr port} {
	yield
	# ::tfast::http::handle $socket $addr $port
	puts [time {::tfast::http::handle $socket $addr $port}]
    }

    
}
