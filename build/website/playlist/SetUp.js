/* Copyright (C) 2024 Mark D. Blackwell.
    All rights reserved.
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
*/
/* Ref.
https://discourse.elm-lang.org/t/escaping-from-npm/7597/18
https://ellie-app.com/hk5Mr29zxhza1
https://ellie-app.com/new
https://elm-tooling.github.io/elm-tooling-cli/
https://flaviocopes.com/javascript-async-defer/
https://flaviocopes.com/javascript-async-defer/#blocking-rendering
https://gist.github.com/dbj/7a1201072d098358dea3d4c3ea13c3d9
https://github.com/swc-project/swc
https://guide.elm-lang.org/optimization/lazy
https://janiczek-ellies.builtwithdark.com/
https://learnyouahaskell.com/for-a-few-monads-more#state
https://package.elm-lang.org/packages/elm/browser/latest/Browser#application
https://package.elm-lang.org/packages/elm/browser/latest/Browser#element
https://package.elm-lang.org/packages/folkertdev/elm-state/latest/State
https://package.elm-lang.org/packages/sli/loadingstate/latest/LoadingState
https://stackoverflow.com/questions/46428129/understanding-this-elm-url-parser-parser-type-declaration/46432677#46432677
https://stackoverflow.com/questions/69198003/debugger-says-layout-forced-problem-in-firefox/70864558#70864558
https://www.youtube.com/@Ellie_editor/videos
*/
(function() {
        let app;

// Prevent Firefox console warning, "Layout was forced before the page."
        window.addEventListener('load', function() {
                app = Elm.Main.init({
                        node: document.querySelector('main'),
                });
        });
})();
