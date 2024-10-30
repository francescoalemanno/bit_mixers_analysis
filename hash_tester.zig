const std = @import("std");
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

pub fn uint16(input: u16) u16 {
    //https://github.com/skeeto/hash-prospector
    // 3-round xorshift-multiply (-Xn3)
    // bias = 0.0045976709018820602
    var x: u16 = input;
    x = (x ^ (x >> 7)) *% 0x2993;
    x = (x ^ (x >> 5)) *% 0xe877;
    x = (x ^ (x >> 9)) *% 0x0235;
    return x ^ (x >> 10);
}
fn uint32(input: u32) u32 {
    // https://github.com/skeeto/hash-prospector
    var x = input;
    x = (x ^ (x >> 17)) *% 0xed5ad4bb;
    x = (x ^ (x >> 11)) *% 0xac4c1b51;
    x = (x ^ (x >> 15)) *% 0x31848bab;
    return x ^ (x >> 14);
}
pub fn uint64(input: u64) u64 {
    // https://github.com/jonmaiga/mx3
    // https://github.com/jonmaiga/mx3/blob/48924ee743d724aea2cafd2b4249ef8df57fa8b9/mx3.h#L17
    const C = 0xbea225f9eb34556d;
    var x = input;
    x = (x ^ (x >> 32)) *% C;
    x = (x ^ (x >> 29)) *% C;
    x = (x ^ (x >> 32)) *% C;
    return x ^ (x >> 29);
}

fn Oracle(uxy: type) type {
    return struct {
        var rng = default_rng();
        pub fn oracle(_: uxy) uxy {
            return @This().rng.random().int(uxy);
        }
    };
}

pub fn main() !void {
    {
        const oracle_f = oracle_eval_f(u16);
        _ = try test_hasher(u16, "newhash16", newhash16, oracle_f);
        _ = try test_hasher(u16, "hash16_xm3", uint16, oracle_f);
        _ = try test_hasher(u16, "oracle16", Oracle(u16).oracle, oracle_f);
    }
    {
        const oracle_f = oracle_eval_f(u32);
        _ = try test_hasher(u32, "std.hash.uint32", std.hash.uint32, oracle_f);
        _ = try test_hasher(u32, "newhash32", newhash32, oracle_f);
        _ = try test_hasher(u32, "triple32", uint32, oracle_f);
        _ = try test_hasher(u32, "oracle32", Oracle(u32).oracle, oracle_f);
    }
    {
        const oracle_f = oracle_eval_f(u64);
        _ = try test_hasher(u64, "mixer_none", mixer_none, oracle_f);
        _ = try test_hasher(u64, "mixer_bad", mixer_bad, oracle_f);
        _ = try test_hasher(u64, "murmur3", murmur3, oracle_f);
        _ = try test_hasher(u64, "murmur3_v13", murmur3_variant13, oracle_f);
        _ = try test_hasher(u64, "moremur", moremur, oracle_f);
        _ = try test_hasher(u64, "mx3", uint64, oracle_f);
        _ = try test_hasher(u64, "oracle64", Oracle(u64).oracle, oracle_f);
    }
}

pub fn test_hasher(uxy: type, name: []const u8, hasher: fn (uxy) uxy, oracle_v: [2]f64) !Score {
    var rng = default_rng();
    const N = (1 << @min(@max(24, @bitSizeOf(uxy)), 32)) - 1;
    var stats = Accumulator(uxy){};
    const lxy = std.math.Log2Int(uxy);
    var iter: usize = 1;
    const sN = std.math.sqrt(N);
    var sus: usize = 0;
    while (iter < N) {
        for (0..sN) |_| {
            const v: uxy = rng.random().int(uxy);
            const w: uxy = hasher(v);
            const i: lxy = rng.random().uintAtMost(lxy, ~@as(lxy, 0));
            const x = w ^ hasher(v ^ (@as(uxy, 1) << i));
            stats.bidim(x);
            iter += 1;
        }
        const data = stats.get();
        const delta = @abs((data[2] - oracle_v[0]) / oracle_v[1]);
        std.debug.print("{s:20} bias=({d:11.5}{d:11.5}) R={d:.4} B={d:4.2} Δ={d:.2}      \r", .{
            name,
            data[0],
            data[1],
            data[2],
            std.math.log2(stats.fiter),
            delta,
        });
        if (delta > 1) {
            sus += 1;
            if (sus > 10) break;
        } else {
            sus = 0;
        }
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
        pub fn bidim(self: *Stats, x: u64) void {
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
                    const v1 = @max(1 - m1i * m1i, 0.0);
                    const v2 = @max(1 - m1j * m1j, 0.0);
                    maxcorr = @max(@abs(ce) / std.math.sqrt(v1 * v2), maxcorr);
                }
            }
            const err = @max(maxdelta, maxcorr) * std.math.sqrt(self.fiter);
            return .{ maxdelta, maxcorr, err };
        }
    };
}

fn default_rng() std.Random.Pcg {
    const see: u64 = 0xe9babc8ca1dac6bb;
    return std.Random.Pcg.init(see);
}

pub fn oracle_eval_f(uxy: anytype) [2]f64 {
    var rng = default_rng();
    var stats = Accumulator(uxy){};
    var f0: f64 = 0.0;
    var f1: f64 = 0.0;
    var f2: f64 = 0.0;
    const N = 300000;
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

    // m_sd  ==  Sqrt[2] InverseErf[-1 + 2 csp^(1/b)]/. csp -> 0.99999 /. b -> 64
    // csp == success probability
    // b == log2(number of tests)
    const m_sd = 1.5 * @sqrt(2 * @log(2.0) * @bitSizeOf(uxy));
    return .{ avg_f1, m_sd * sd };
}
