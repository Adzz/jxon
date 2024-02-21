## Masking

The idea with masking is if we bitwise AND the mask with some input, if the result of that is the same as the mask then all the bits that were set in the mask are set in the input, meaning they are equal.

This feels like a good way to determine if some section of the JSON input is a given character. I wonder if you could chunk off the smallest section that will uniquely identify what we are parsing given the context, then pass it through a bunch of masks to determine what step we do next? Or even execute them all in parallel?
