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


## Advanced

tfast <cmd> [options]

### Commands

#### Utils

* cleanup - Cleanup routes

* print [options] - print router configs
  * -routes - print only routes
  * -interceptors - print only interceptors
  * -middlewares - print only middlewares
  * -all - print routes, interceptors and middlewares

* route match <method> <path> - Search by route and return a Route object or empty string
  `tfast route match get /path`

* serve [options] 
  * -host - Default is localhost
  * -port - Default is 3000
  * -workers - Threads number, default is 1
  * -backend <backend-name>: Backend name, default is pure
    * pure - Pure TCL http server
    * easy_beast - Boost beast http server


#### Http methods

* get
    `tfast get /path {req { render -text "hello"}}`
* head
    `tfast head * {req { render }}`
* options
    `tfast options * {req { render }}`
* post
    `tfast post /path {req { render -text [req body]}}`
* put
    `tfast put /path {req { render -text [req body]}}`
* delete
    `tfast delete /path {req { render }}`
* patch
    `tfast patch /path {req { render -text "hello"}}`
* any or *
    `tfast * /path {req { render -text "hello"}}`

#### Middlewares

A route is characterized by an action, namely `{req {render -text "" }}`. 

A middleware can be connected at the beginning or end of a route. 
When starting, it only receives a request parameter and can return the same request or modify it, or return a response, thus 
When connected at the end, it receives a request and a response and can only return one response, new or modified.ending the request.

**Enter middleware**

`tfast ns /path -enter {req {}}`

**Leave middleware**

`tfast ns /path -leave {req resp {}}`

Enter and leave middleware

```tcl
  tfast get / \
    {req {}} \      ;# first middleware
    {req {}} \      ;# second middleware
    {req {}} \      ;# route action
    {req resp {}}   ;# last middleware
```

#### Interceptors


The interceptors can be defined by path or status code and path. It receive the request and the response and should return a response

```tcl
  tfast ns /path -recover {req resp {}} # catch all on /path
  tfast ns 500 * {req resp {}} # cacth all with status 500
```

#### Namespace

We can also define middleware and routes for a given namespace or path

* ns [options]
  * -enter - Enter middlewares
  * -leave - Leave middleware
  * -status - Status code interceptor
  * -recover - Recover interceptor

```tcl
  tfast ns * \
    -enter {req {}} \
    -leave {req resp {}} \
    -status 400 {req resp {}} \
    -recover {req resp {}} 
```

and we can define routes with subroutes, interceptors and middlewares using namespaces.

```tcl

  tfast ns /user {
    
    enter {req {}}        ;# middleware

    leave {req resp {}}   ;# middleware
    
    401 {req {}}          ;# http code interceptor
    
    get / {req {}}        ;# http action
    
    get /:id {req {}}     ;# http action
    
    post / {req {}}       ;# http action
    
    put / {req {}}        ;# http action
    
    delete /:id {req {}}  ;# http action
    
    ns /nested {
      get / {req {}}      ;# nested route
    }

  }
```
