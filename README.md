# First-PIC-Project
<p>This is my first project using PIC MCUs and also my first GitHub repo<br>
It is basically a random number generator with 7 LEDs that show the number in a pattern you would see on a die.</p>

<p>I used a PIC16F690 but it could work on other Mid-Range PICs with little to no modification. Also the patterns for how the LEDs should look for each number are defined in the code so they can be modified for different LED arrangements.</p>

<p>It uses a pseudo-random Fibonacci <a href="https://en.wikipedia.org/wiki/Linear-feedback_shift_register"> linear feedback shift register </a> the seed for which is derived from the noise on a floating pin thus achieving pretty good randomness. The process and the code is explained in more detail in the comments inside the source code file.</p>

# Demo

![Demo Animation](demo.gif)

# License

<p>This code is licensed under the MIT NON-AI License which can be found here: <br>
<a href="https://github.com/non-ai-licenses/non-ai-licenses"> https://github.com/non-ai-licenses/non-ai-licenses </a> <br>
Credit to <a href="https://github.com/axel22"> axel22 </a>.</p>
