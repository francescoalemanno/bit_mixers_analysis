const std = @import("std");

pub fn Oracle(uxy: type) type {
    return struct {
        var rng = default_rng();
        pub fn oracle(_: uxy) uxy {
            return @This().rng.random().int(uxy);
        }
    };
}

pub fn mixer_none(x: u64) u64 {
    return x *% 0xbea225f9eb34556d;
}

pub fn mixer_bad(raw_input: u64) u64 {
    const SPL = packed struct { a: u32, b: u32 };
    var x: SPL = @bitCast(raw_input);
    x.a = std.hash.uint32(x.a);
    x.b = std.hash.uint32(x.b);
    return @bitCast(x);
}

pub fn murmur3(y: u64) u64 {
    //http://zimbry.blogspot.com/2011/09/better-bit-mixing-improving-on.html
    var key: u64 = y;
    key ^= (key >> 33);
    key *%= 0xff51afd7ed558ccd;
    key ^= (key >> 33);
    key *%= 0xc4ceb9fe1a85ec53;
    key ^= (key >> 33);
    return key;
}

pub fn murmur3_variant13(y: u64) u64 {
    //http://zimbry.blogspot.com/2011/09/better-bit-mixing-improving-on.html // new variant in blog post
    var key: u64 = y;
    key ^= (key >> 30);
    key *%= 0xbf58476d1ce4e5b9;
    key ^= (key >> 27);
    key *%= 0x94d049bb133111eb;
    key ^= (key >> 31);
    return key;
}

pub fn moremur(y: u64) u64 {
    //https://mostlymangling.blogspot.com/2019/12/
    var x = y;
    x ^= x >> 27;
    x *%= 0x3C79AC492BA7B653;
    x ^= x >> 33;
    x *%= 0x1C69B3F74AC4AE35;
    x ^= x >> 27;
    return x;
}

pub fn newhash32(input: u32) u32 {
    //devised using "uint64" as a starting point
    const X = 0xbea225f9;
    var key: u32 = input;
    inline for (.{ 16, 0, 15, 0, 16, 0, 15 }) |fold| {
        key = if (fold == 0) (key *% X) else key ^ (key >> fold);
    }
    return key;
}

pub fn newhash16(input: u16) u16 {
    //devised using "uint16" as a starting point
    const X = 0xbea3;
    var key: u16 = input;
    inline for (.{ 8, 0, 7, 0, 8, 0, 7 }) |fold| {
        key = if (fold == 0) (key *% X) else key ^ (key >> fold);
    }
    return key;
}
pub fn nasam(input: u64) u64 {
    // http://mostlymangling.blogspot.com/2020/01/nasam-not-another-strange-acronym-mixer.html
    var x = input;
    x ^= std.math.rotr(u64, x, 25) ^ std.math.rotr(u64, x, 47);
    x *%= 0x9E6C63D0676A9A99;
    x ^= x >> 23 ^ x >> 51;
    x *%= 0x9E6D62D06F6A9A9B;
    x ^= x >> 23 ^ x >> 51;
    return x;
}
pub fn uint16(input: u16) u16 {
    return int(u16, input);
}
pub fn uint32(input: u32) u32 {
    return int(u32, input);
}
pub fn uint64(input: u64) u64 {
    return int(u64, input);
}

/// Applies a bit-mangling transformation to an unsigned integer type `T`.
/// Optimized per type: for `u16` and `u32`, Skeeto's xorshift-multiply; for `u64`, Maiga's mx3.
/// Falls back on an avalanche pattern for other unsigned types, ensuring high entropy.
/// Only unsigned types are accepted; signed types will raise a compile-time error.
pub fn int(comptime T: type, input: T) T {
    const tInfo = @typeInfo(T).int;
    if (tInfo.signedness != .unsigned) @compileError("type has to be unsigned integer");
    var x = input;
    switch (T) {
        u16 => {
            //https://github.com/skeeto/hash-prospector
            // 3-round xorshift-multiply (-Xn3)
            // bias = 0.0045976709018820602
            x = (x ^ (x >> 7)) *% 0x2993;
            x = (x ^ (x >> 5)) *% 0xe877;
            x = (x ^ (x >> 9)) *% 0x0235;
            x = x ^ (x >> 10);
        },
        u32 => {
            // https://github.com/skeeto/hash-prospector
            x = (x ^ (x >> 17)) *% 0xed5ad4bb;
            x = (x ^ (x >> 11)) *% 0xac4c1b51;
            x = (x ^ (x >> 15)) *% 0x31848bab;
            x = x ^ (x >> 14);
        },
        u64 => {
            // https://github.com/jonmaiga/mx3
            // https://github.com/jonmaiga/mx3/blob/48924ee743d724aea2cafd2b4249ef8df57fa8b9/mx3.h#L17
            const C = 0xbea225f9eb34556d;
            x = (x ^ (x >> 32)) *% C;
            x = (x ^ (x >> 29)) *% C;
            x = (x ^ (x >> 32)) *% C;
            x = x ^ (x >> 29);
        },
        else => {
            // this construction provides robust avalanche properties, but it is not optimal for any given size.
            const B = comptime @bitSizeOf(T) >> 2;
            if (B == 0) @compileError("unimplemented");
            const B1 = comptime B << 1; //make sure even
            const B2 = comptime B1 | 1; //make sure odd
            const C = comptime (0x9E6C63D0676A9A99bea225f9eb34556d & ((1 << @bitSizeOf(T)) - 1)) | 1; // make sure odd
            x = (x ^ (x >> B1)) *% C;
            x = (x ^ (x >> B2)) *% C;
            x = (x ^ (x >> B1)) *% C;
            x = x ^ (x >> B2);
        },
    }
    return x;
}

test "bit manglers" {
    try std.testing.expect(int(u16, 1) == 0x2880);
    try std.testing.expect(int(u32, 1) == 0x42741D6);
    try std.testing.expect(int(u64, 1) == 0x71894DE00D9981F);
    try std.testing.expect(int(u48, 1) == 0x4A4A7B6E4FB);
}

const wu = u13;
pub fn weird(x: wu) wu {
    return int(wu, x);
}
pub fn main() !void {
    const oracle_wu = oracle_eval_f(wu);
    _ = try test_hasher(wu, "weird", weird, oracle_wu);

    const oracle_16 = oracle_eval_f(u16);
    _ = try test_hasher(u16, "newhash16", newhash16, oracle_16);
    _ = try test_hasher(u16, "hash16_xm3", uint16, oracle_16);
    _ = try test_hasher(u16, "oracle16", Oracle(u16).oracle, oracle_16);
    const oracle_32 = oracle_eval_f(u32);
    _ = try test_hasher(u32, "std.hash.uint32", std.hash.uint32, oracle_32);
    _ = try test_hasher(u32, "newhash32", newhash32, oracle_32);
    _ = try test_hasher(u32, "triple32", uint32, oracle_32);
    _ = try test_hasher(u32, "oracle32", Oracle(u32).oracle, oracle_32);
    const oracle_64 = oracle_eval_f(u64);
    _ = try test_hasher(u64, "mixer_none", mixer_none, oracle_64);
    _ = try test_hasher(u64, "mixer_bad", mixer_bad, oracle_64);
    _ = try test_hasher(u64, "murmur3", murmur3, oracle_64);
    _ = try test_hasher(u64, "murmur3_v13", murmur3_variant13, oracle_64);
    _ = try test_hasher(u64, "moremur", moremur, oracle_64);
    _ = try test_hasher(u64, "mx3", uint64, oracle_64);
    _ = try test_hasher(u64, "nasam", nasam, oracle_64);
    _ = try test_hasher(u64, "oracle64", Oracle(u64).oracle, oracle_64);
}

pub fn test_hasher(uxy: type, name: []const u8, hasher: fn (uxy) uxy, oracle_v: [2]f64) !Score {
    var rng = default_rng();
    var stats = Accumulator(uxy){};
    const lxy = std.math.Log2Int(uxy);
    var iter: usize = 1;
    var sus: f64 = 0;
    while (sus < 1e4) {
        for (0..256) |_| {
            const v: uxy = rng.random().int(uxy);
            const w: uxy = hasher(v);
            const i: lxy = rng.random().uintAtMost(lxy, @bitSizeOf(uxy) - 1);
            const x = w ^ hasher(v ^ (@as(uxy, 1) << i));
            stats.bidim(x);
            iter += 1;
        }
        const data = stats.get();
        const delta = (data[2] - oracle_v[0]) / oracle_v[1];
        sus += @abs(delta * delta - 1);
        std.debug.print("{s:20} bias=({d:.5} {d:.5}) R={d:11.4} B={d:4.2} Δ={d:11.2} {d:13.2}    \r", .{
            name,
            data[0],
            data[1],
            data[2],
            std.math.log2(stats.fiter),
            delta,
            sus,
        });
    }
    const data = stats.get();
    const score: Score = .{ .name = name, .f1 = data[0], .f2 = data[1], .badness = (data[2] - oracle_v[0]) / oracle_v[1], .survival = iter };
    std.debug.print("\n\n", .{});
    return score;
}

const Score = struct {
    name: []const u8,
    f1: f64,
    f2: f64,
    badness: f64,
    survival: u64,
};

fn Accumulator(uxy: anytype) type {
    const bitlen = @bitSizeOf(uxy);
    const lxy = std.math.Log2Int(uxy);
    return struct {
        const Stats = @This();
        const eps = 0;
        A: [bitlen][bitlen]f64 = [_][bitlen]f64{[_]f64{eps} ** bitlen} ** bitlen,
        M2: [bitlen][bitlen]f64 = [_][bitlen]f64{[_]f64{eps} ** bitlen} ** bitlen,
        C2: [bitlen][bitlen]f64 = [_][bitlen]f64{[_]f64{eps} ** bitlen} ** bitlen,
        C1: [bitlen]f64 = [_]f64{eps} ** bitlen,
        M1: [bitlen]f64 = [_]f64{eps} ** bitlen,
        fiter: f64 = eps,
        pub fn bidim(self: *Stats, x: uxy) void {
            self.fiter += 1;
            for (0..bitlen) |i_| {
                const i: lxy = @intCast(i_);
                const bi: f64 = if ((x >> i) & 1 == 0) -1 else 1;
                self.M1[i] += bi;
                self.C1[i] += 1.0;
                for (0..bitlen) |j_| {
                    const j: lxy = @intCast(j_);
                    const bj: f64 = if ((x >> j) & 1 == 0) -1 else 1;
                    self.A[i][j] += bj;
                    self.C2[i][j] += 1.0;
                    self.M2[i][j] += bi * bj;
                }
            }
        }
        pub fn get(self: *const Stats) [3]f64 {
            const A = self.A;
            const M1 = self.M1;
            const M2 = self.M2;
            const C1 = self.C1;
            const C2 = self.C2;
            var avgdelta: f64 = 0;
            var avgcnt: f64 = 0;
            var maxdelta: f64 = 0.0;
            var maxcorr: f64 = 0.0;
            for (0..bitlen) |i| {
                for (0..bitlen) |j| {
                    if (i == j) continue;
                    const re = @abs(A[i][j] / C2[i][j]);
                    avgdelta += re;
                    avgcnt += 1.0;
                    maxdelta = @max(maxdelta, re);
                    const m2ij = M2[i][j] / C2[i][j];
                    const m1i = M1[i] / C1[i];
                    const m1j = M1[j] / C1[j];
                    const ce = m2ij - m1i * m1j;
                    maxcorr = @max(@abs(ce), maxcorr);
                }
            }
            const err = @max(maxdelta, maxcorr) * std.math.sqrt(self.fiter);
            return .{ maxdelta, maxcorr, err };
        }
    };
}

pub fn default_rng() std.Random.Pcg {
    const see: u64 = 0xe9babc8ca1dac6bb;
    return std.Random.Pcg.init(see);
}

pub fn oracle_eval_f(uxy: anytype) [2]f64 {
    var rng = default_rng();
    var stats = Accumulator(uxy){};
    var f0: f64 = 0.0;
    var f1: f64 = 0.0;
    var f2: f64 = 0.0;
    const N = 3000000;
    const sN = N / 10;
    for (0..N) |x| {
        stats.bidim(rng.random().int(uxy));
        if (x >= sN) {
            const data = stats.get();
            const estimate = data[2];
            f0 += 1.0;
            f1 += estimate;
            f2 += estimate * estimate;
        }
    }
    const avg_f1 = f1 / f0;
    const avg_f2 = f2 / f0;
    const sd = std.math.sqrt(@max(avg_f2 - avg_f1 * avg_f1, 0.0));
    return .{ avg_f1, sd };
}
