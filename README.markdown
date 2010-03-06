RemoteParameter
===========================

@togi reminded me the other day of the horrible annoyance that is tweaking UI-related variables in iPhone apps until you get it just right, by changing-recompiling-installing-navigating-looking and repeating ad nauseum, and suggested that it should be doable with some KVO magic and maybe some DO. And you know what? It is!

Say you have a view somewhere. It has a color. You have heaps and bounds of views on top of it, with alpha and gloss and I don't know what. You want it to look *just right*, so you need to do it on the device, and you need to do it in code. Now, it's as simple as:
<code>
    #include "RemoteParameter.h"
    ...
    
  [colorView shareKeyPath:@"backgroundColor" as:@"colorView"];
</code>

... adding RemoteParameter.[m|h], AsyncSocket.[m|h] and CFNetwork.framework to your project, and boom, you're done! Launch ParameterController.app, browse to your instance, and edit away.

Tutorial
---------------
<object width="512" height="384"><param name="movie" value="http://www.youtube.com/v/2ffDsZInBss&hl=en_US&fs=1&"></param><param name="allowFullScreen" value="true"></param><param name="allowscriptaccess" value="always"></param><embed src="http://www.youtube.com/v/2ffDsZInBss&hl=en_US&fs=1&" type="application/x-shockwave-flash" allowscriptaccess="always" allowfullscreen="true" width="512" height="384"></embed></object>