const fs = require('fs');
let code = fs.readFileSync('app/lib/core/routing/app_router.dart', 'utf8');

// 1. Add the route
const targetRoute = "path: '/patient/new',";
const newRoute = `path: '/gramnidan/register/:id',
      builder: (context, state) => GramNidanRegisterDetailScreen(
        registerId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/patient/new',`;
code = code.replace(targetRoute, newRoute);

fs.writeFileSync('app/lib/core/routing/app_router.dart', code);
console.log('Fixed routing!');
