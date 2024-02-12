/* Copyright (C) 2023 Mark D. Blackwell.
    All rights reserved.
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
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
