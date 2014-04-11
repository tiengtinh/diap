## Diap

Dependancy Injection with routing support for ExpressJs project.

```
install diap
```

## Example Usage

server.coffee
```coffeescript
diap          = require('diap')

diap.setup(
	app: app
	scanFolders: [fs.realpathSync('./server/app')]
	routes: require('./routes')
	classPostfixs: [ #filename with these postfix would be Class Type (autowired with new OuserService()). Others are value type
		'_controller'
		'_service'
	]
	globalMiddlewares: 
		whenNot: 
			public: (res, req, next) ->
				console.log 'whenNot middleware'
				next()
		#when:
)
```

routes.coffee
```coffeescript
routes = [	
	{
		path: '/api/user',
		method: 'GET',
		run: [ 
			'apiController.users'
		]
	}
	{
		path: '/api/test',
		method: 'GET',
		run: [ 
			'apiController.test'
		]
	}
	{
		path: '/partial/:name',
		method: 'GET',
		run: [ 
			(req, res, next) ->
				console.log 'before partial'
				next()
			(req, res) ->
				res.render('partials/' + req.params.name)
		]
		public: true
	}
	{
		path: '*',
		method: 'GET',
		run: [ 
			'serverController.layout'
		]
		public: true
	}
]

module.exports = routes
```

api_controller.coffee
```coffeescript
class ApiController
	constructor: (@ouserService) ->

	users: (req, res) =>   
		@ouserService.list().then (users) ->
			res.json users

	test: (req, res) =>   		
		res.json 'test'

module.exports = ApiController
```
