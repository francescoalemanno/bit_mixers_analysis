**Title**: Analysis of Hash Mixers and Bit Mangling Quality in Zig

**Description**:
This PR compares a variety of hash mixing functions and evaluates their effectiveness using custom statistical analysis and bias tests. The purpose of the comparison is to assess each function's robustness in distributing bits evenly and reducing patterns that can lead to poor hash distribution. Specifically, we focus on bias measurements and survival rates of each mixer.

**Summary of Compared Mixers and Evaluated Methods**:

1. **mixer_none**: A basic, minimalistic mixer using a single multiplicative constant. This serves as a baseline to evaluate the benefits of more complex operations.

2. **mixer_bad**: Utilizes Zig's `std.hash.uint32` on split `u32` chunks. This approach illustrates the limitations of separately hashing each part without further mixing.

3. **murmur3 & murmur3_variant13**: Variants based on Murmur3 hash functions with different shifts and constants, known for strong bit-mixing characteristics, used widely in high-performance hashing.

4. **moremur**: An alternative bit-mixing approach inspired by [mostlymangling blog](https://mostlymangling.blogspot.com/2019/12), focusing on lower bias and efficient bit-spreading.

5. **triple32, hash16_xm3**: A high-quality `u32` (`u16`) mixing function, derived from [`hash-prospector`](https://github.com/skeeto/hash-prospector), optimized to pass various bias and avalanche tests.

6. **mx3, newhash32, newhash16**: Implementations based on [Jon Maiga’s mx3 hash](https://github.com/jonmaiga/mx3), modified to accommodate `u64`, `u32`, and `u16` inputs, and utilizing unique folding strategies.

Each function was tested using a two-dimensional extreme value bias check and estimates "badness" scores based on distribution irregularities across bit patterns. Key parameters for evaluation:
   - `bias` bias in 1d avalanche, bias in 2d correlation.
   - `Δ`: Quantified as deviation from an "oracle" distribution, approximating ideal randomness.
   - `B`: The log2 number of test iterations before either failing or reaching the max-iteration cap.

**Results**:
Each mixing function's performance is printed, showing bias and "badness" score over iterations. The iterative test stops upon detecting irregular bias patterns or after achieving the survival threshold, as seen in the print output in `test_hasher`.

```zig
// 16 BIT
           newhash16 bias=(    0.00559    0.00718) R=5.1038  B=18.95  Δ=1.13      
          hash16_xm3 bias=(    0.00386    0.00574) R=5.3702  B=19.74  Δ=1.28      <- winner
            oracle16 bias=(    0.00040    0.00056) R=2.3127  B=24.03  Δ=0.44      
// 32 BIT
     std.hash.uint32 bias=(    0.10606    0.28615) R=6.5752  B=9.04   Δ=2.33      
           newhash32 bias=(    0.00011    0.00019) R=4.7689  B=29.19  Δ=1.05      
            triple32 bias=(    0.00003    0.00005) R=3.4455  B=32.08  Δ=0.12      <- winner
            oracle32 bias=(    0.00004    0.00004) R=2.9764  B=32.08  Δ=0.21   
// 64 BIT
          mixer_none bias=(    0.97656    0.80989) R=15.6250 B=8.00   Δ=11.91      
           mixer_bad bias=(    0.60938    0.57108) R=9.7500  B=8.00   Δ=5.95      
             murmur3 bias=(    0.07956    0.17884) R=5.1119  B=9.67   Δ=1.25      
         murmur3_v13 bias=(    0.04437    0.10137) R=5.9135  B=11.73  Δ=2.06      
             moremur bias=(    0.00298    0.00610) R=4.9051  B=19.30  Δ=1.04      
                 mx3 bias=(    0.00004    0.00006) R=3.3505  B=28.67  Δ=0.54      <- winner
```

