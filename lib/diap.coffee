_     = require('underscore')
fs    = require('fs')
path  = require('path')
di    = require('di')
clc   = require('cli-color')
g_injector = null

class AppLoader
	constructor: (app, scanFolders, classPostfixs, routes, globalMiddlewares) ->    
	
		controllers = []
		files = []

		module = 
			'app': ['value', app]

		for folder in scanFolders			
			filesInFolder = @getFileNamesIn(folder, classPostfixs)			
			files = files.concat(filesInFolder)
		console.log('')				

		files.forEach (file) ->			
			module[if file.isClass then file.instanceName else file.className] = [
				if file.isClass then 'type' else 'value'
				file.source
			]

			if file.isClass then controllers.push file.instanceName

		g_injector = injector = new di.Injector([module])	
		console.log 'controllers', controllers

		if not routes
			#the first controller should be call last in case of its contaning of '*' route
			topCtrl = controllers.shift()
			controllers.push(topCtrl)
			invokedControllers = null
			routes = []
			
			eval("""
				injector.invoke(function(#{controllers.join(', ')}) {					
					invokedControllers = arguments;
				})
			""")

			for controller_i, controllerClass of invokedControllers				
				if controllerClass.routes					
					controllerClass.routes.forEach (route, route_i) ->						
						route.run.forEach (run, run_i) ->
							route.run[run_i] = controllers[controller_i] + '.' + run
							console.log 'run', run
					
					routes = routes.concat controllerClass.routes
			

		routes.forEach (route, route_i) ->

			route.run.forEach (middleware, run_i) ->			
				if typeof middleware is 'string'					
					insFun = null
					instance = middleware.split('.')[0]
					method   = middleware.split('.')[1]								
					eval("""
						injector.invoke(function(#{instance}) {
							insFun = #{instance}.#{method}
						})
					""")

					if not insFun then throw new Error("#{instance}.#{method} does not exit")
					
					routes[route_i].run[run_i] = insFun

			if globalMiddlewares and globalMiddlewares.when
				unshiftedMiddleware = []			

				for name, func of globalMiddlewares.when
					if route[name] #check the current route satisfy the condition to have this middleware
						if typeof func is 'string' #is a string reference to a class.function
							insFun = null
							instance = func.split('.')[0]
							method   = func.split('.')[1]
							eval("""
								injector.invoke(function(#{instance}) {
									insFun = #{instance}.#{method}
								})
							""")

							if not insFun then throw new Error("#{instance}.#{method} does not exit")

							unshiftedMiddleware.push insFun
						else # is a function
							unshiftedMiddleware.push func

				route.run.unshift.apply route.run, unshiftedMiddleware

			if globalMiddlewares and globalMiddlewares.whenNot
				unshiftedMiddleware = []
				for name, func of globalMiddlewares.whenNot
					if !route[name] #check the current route satisfy the condition to have this middleware
						if typeof func is 'string' #is a string reference to a class.function
							insFun = null
							instance = func.split('.')[0]
							method   = func.split('.')[1]
							eval("""
								injector.invoke(function(#{instance}) {
									insFun = #{instance}.#{method}
								})
							""")

							if not insFun then throw new Error("#{instance}.#{method} does not exit")

							unshiftedMiddleware.push insFun
						else # is a function
							unshiftedMiddleware.push func

				route.run.unshift.apply route.run, unshiftedMiddleware

			args = _.flatten([route.path, route.run])

			console.info clc.bold(route.method.toUpperCase()), '\t', route.path
			
			switch route.method.toUpperCase()
				when 'GET'
					app.get.apply(app, args)
				when 'POST'
					app.post.apply(app, args)
				when 'PUT'
					app.put.apply(app, args)
				when 'DELETE'
					app.delete.apply(app, args)
				else
					throw new Error('Invalid HTTP method specified for route ' + route.path)			
		

	getFileNamesIn: (folder, classPostfixs) ->
		result = []
		
		filos = fs.readdirSync folder #filos = files and folders

		if filos.length > 0
			filos.forEach (filo) =>

				#not a folder
				if @isFile(filo)
					console.info clc.cyan(filo)
					filename = @filenamize filo
					instanceName = @camelize filename
					className = @capitalize instanceName
					isClass = @isClassType filename, classPostfixs
					file = 
						fileName 		: filename
						className		: className
						instanceName	: instanceName
						isClass 		: isClass						
						source		 	: require(path.join(folder, filo))
					
					result.unshift file

				else #a folder
					@getFileNamesIn(path.join(folder, filo), classPostfixs).forEach (file) ->
						result.push file

		result

	filenamize: (str) ->
		str.replace(/\.js/, "").replace(/\.coffee/, "")

	capitalize: (str) ->
		str.replace /(?:^|\s)\S/, (ch) ->
			ch.toUpperCase()

	camelize: (str) ->
		str.replace /_(\w)/g, (ch) ->
			ch.substring(1).toUpperCase()

	endsWith: (str, ends) ->
		return true if ends is ''		
		return false if str == null || ends == null		
		str = String(str)
		ends = String(ends)
		str.length >= ends.length && str.slice(str.length - ends.length) == ends

	isFile: (name) ->
		@endsWith(name, '.coffee')		

	isClassType: (name, classPostfixs) ->
		for each in classPostfixs			
			if @endsWith(name, each)   
				return true
		false

	###uniquizeArray: (array) ->
		output = {}
		output[array[key]] = array[key] for key in [0...array.length]
		value for key, value of output

	isArrayUnique: (array) ->
		array.length == @uniquizeArray(array).length###

diap = 
	setup: (options) ->
		defaults = 
			app: null
			scanFolders: []
			classPostfixs: [
				'_controller'
				'_service'
			]
			routes: null
			globalMiddlewares:
				when: []
				whenNot: []
		
		options = defaults extends options
		
		new AppLoader(options.app, options.scanFolders, options.classPostfixs, options.routes, options.globalMiddlewares)	


module.exports = 
	setup: diap.setup
	injector: ->
		g_injector
	
