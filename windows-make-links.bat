cd build\website\player

erase LatestFiveAsk.html
mklink LatestFiveAsk.html ..\playlist\LatestFiveAsk.html

erase LatestFiveDemo.html
mklink LatestFiveDemo.html ..\playlist\LatestFiveDemo.html

erase LatestFiveLike.html
mklink LatestFiveLike.html ..\playlist\LatestFiveLike.html

cd dynamic
erase LatestFiveNew.html
mklink LatestFiveNew.html ..\..\playlist\dynamic\LatestFiveNew.html
