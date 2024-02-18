/* Copyright (C) 2024 Mark D. Blackwell.
    All rights reserved.
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
*/
/* Ref.
https://ellie-app.com/new
qplaylist-remember/src/remember-source/SetUp.js
https://elm-tooling.github.io/elm-tooling-cli/
https://discourse.elm-lang.org/t/escaping-from-npm/7597/18
https://flaviocopes.com/javascript-async-defer/
*/
(function() {
    const functionDealWithElm = function() {

        const functionAttachNode = function() {
            return Elm.Main.init({
                node: document.querySelector('body'),
                flags: {
                    channel: functionChannel()
                }
            });
        };
        const functionChannel = function() {
            //location.search always includes a leading question mark.
            const queryParameters = window.location.search.slice(1);

            //Some browsers lack the URLSearchParams function, so perhaps don't use it.
            return queryParameters;
        };

        functionStorageSubscribe(functionAttachNode());
    };

    functionDealWithElm();
})();
