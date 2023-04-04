# PSRDNoise for Metal Shading Language

![Example output of a fractal noise sum](psrdnoise.png)

MSL implementations of `prsdnoise` ([2D](Application/Main.metal#L40) & [3D](Application/Main.metal#L132)) translated from the original GLSL: https://github.com/stegu/psrdnoise.

---

The entire content of this repository is in the public domain, with the exception of the `psrdnoise` ([2D](Application/Main.metal#L38) & [3D](Application/Main.metal#L132)) functions implemented in Metal Shading Language (MSL), which were adapted from the original GLSL implementations ([2D](https://github.com/stegu/psrdnoise/blob/4d627ff/src/psrdnoise2-min.glsl#L5) & [3D](https://github.com/stegu/psrdnoise/blob/4d627ff/src/psrdnoise3-min.glsl#L10)) that come with an MIT license:

Copyright 2021 Stefan Gustavson and Ian McEwan

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
