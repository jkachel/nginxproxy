# nginxproxy

This is a pretty simple proxy built using nginx that exists to make it somewhat easier to run multiple Docker containers that all need to sit on port 80 or 443. (So, it's more of a multiplexer for those ports than anything.) It was born of a want to not have to shut down Docker containers when I wanted to swap between projects, or if I needed to run a Web app locally for some utility purpose.

It's important to note that this is not a load balancer, and it's not really appropriate for serving things that can't handle static files (so your PHP app that uses FPM needs to have its own actual Web server). ASGI may be OK with some configuration file twiddling, as may WSGI. 

This also has some handy utility stuff to generate self-signed certificates or a CSR so you can add a real cert. It does not support certbot though you can certainly add it if you have a cert authority that can issue you things. (Unless you have this connected to the Internet, Let's Encrypt won't do it.) 

## Building and Running

1. Check out the repo. Then, clone it locally.
2. Update the openssl.cnf file that's in config/ssl/. This has some defaults you'll probably want to change in it. 
3. (Optionally) update the runproxy.sh script. There are two variables up at the top of the file that can be adjusted if you don't want to use the default image (and container) name of nginxproxy and network name of httpproxy. 
4. Build the image. Run "./runproxy.sh -b" and that should build the image and will also create a self-signed certificate for you if there's no cert (and will copy the resulting cert back for you). 
> If you have a cert or want to manually generate a cert, place the cert and the key in config/ssl/cert.pem and config/ssl/cert.pem (respectively). The build process won't overwrite files that are there. 
5. Run the image. Run "./runproxy.sh" to just run it. 

The runproxy.sh script runs the proxy as a daemon so you won't see any output. Run docker log nginxproxy to see logs, or just docker ps to make sure it's actually running, but you should now be able to go to http://localhost and get an nginx start page. HTTPS should work too (with the requisite cert error, unless you gave it a real one). 

There's more customization stuff you can do here - see further down the page.

## Using

By default, this works through some nginx regular expression matching. The server examines the incoming URL and parses out the first segment of the path. That segment becomes the proxy target, and then it just passes the request on to the target *via plain HTTP*. (If it exists - if it doesn't, you'll get a gateway error.)

So, consider this scenario. The proxy is running using the defaults (so the network is named httpproxy) and you're running it using the runproxy script (which exposes ports 80 and 443 to your machine, so you can get to the proxy server normally). Additionally, you have an app named "testapp" that has an Apache server that you want to run behind the proxy at https://localhost/testapp. To make this work, you'd:
1. Run the testapp image. The container will need to be named testapp and it needs to be attached to the httpproxy network: `docker run --name testapp --network httpproxy testapp`
2. Make sure your app is set up to be served from /testapp in its own container. (The proxy will pass the full URI on to the upstream server, so it'll see requests for /testapp/whatever.) 

This does point out a couple of things your app will need to be OK with. 
* It needs to be able to be OK with accepting proxy responses as http, not https. (You can change this in the configuration file if you want, but it defaults to just using HTTP.)
* It needs to expect your actual app to live at /\<container name\>.

There are other things you can set up here - the entire nginx config is in the config/ folder - but this is the basic way to use this.

## More Advanced Usage

The default.conf file has some instructions in it for enabling a blanket rewrite to https for the default host, so take a look at that if that's something you want.

You can set up a virtual host by looking in the config/conf.d/per-container folder. There's a template here that you can use to set up a virtual host for a specific container - this will allow you to add a local DNS entry (via /etc/hosts or equivalent) for your container. For example, if you had an app named "vhostapp" that really didn't like being served from a subfolder for whatever reason, you can use the template to redirect anything going to "vhostapp.local" to the vhostapp container. This is set up so that it'll work even if the container isn't running when the proxy isn't. 

The OpenSSL config is set up so that you can generate a CSR that has Subject Alternate Names (or, in other words, multiple domains). The comments in the file should tell you what you need to do to make that work. The main caveat here is that cert authorities may not like a cert request that includes, say, `.local` domains. (In the use case that I had for this, the cert authority - InCommon - would reject a CSR for a local domain outright.) But, if you have an internal CA or you just want to be able to trust a cert that has a bunch of .local domains in it, you can definitely do that. 

The runproxy.sh has some flags that automate rebuilding (and re-running) the image, and generating the CSR using the image's OpenSSL. Run `runproxy.sh -h` for info (or read it). 

**Logs by default are bind mounted to the logs/ folder** - you should be able to see the access and error logs there if something's going weirdly. 