const std = @import("std");
const rl = @import("raylib");
const rlm = @import("raylib-math");

const Vector2 = rl.Vector2;

const Bird = struct {
    const Self = @This();

    pos: Vector2,
    dir: Vector2, // where do we need to enforce normalization?

    fn init(pos: Vector2, dir: ?Vector2) Self {
        var final_dir: Vector2 = undefined;
        if (dir) |provided| {
            final_dir = provided;
        } else {
            final_dir = Vector2.init(0, 1);
        }

        return Self{
            .pos = pos,
            .dir = final_dir,
        };
    }

    fn draw(self: *const Self) void {
        rl.drawCircleV(self.pos, 5, rl.Color.blue);
    }
};

// for simplicity's sake, we'll just assume a 1,000 x 1,000 grid in the coordinate
// system, and all the caller to specify how that's broken up into subgrids in the
// call to init. We'll just assume square subgrids for now
// We'll want to have nice and even grid sizes, so we'll clamp to the nearest value if
// necessary and emit a warning if we do so
pub fn SimSpace(comptime space_len: u32, comptime subgrid_size: u32) type {
    return struct {
        const Self = @This();

        const n_subgrids = space_len / subgrid_size;

        allocator: std.mem.Allocator,
        grids: [n_subgrids][n_subgrids]Grid,
        space_len: u32,
        grid_len: u32,

        pub fn init(allocator: std.mem.Allocator, n_birds: u32) !Self {
            if (space_len < subgrid_size) {
                @compileError("Subgrid size must be less than or equal to the simulation space size");
            }
            if (space_len % subgrid_size != 0) {
                @compileError("Subgrid size must evenly divide the simulation space size");
            }

            var grids: [n_subgrids][n_subgrids]Grid = undefined;
            for (0..n_subgrids) |i| {
                for (0..n_subgrids) |j| {
                    grids[i][j] = try Grid.init(allocator);
                }
            }

            var gen = std.Random.Xoshiro256.init(@as(u64, @intCast(@max(0, std.time.milliTimestamp()))));
            const random = gen.random();
            for (0..n_birds) |_| {
                const pos = Vector2.init(std.rand.float(random, f32) * space_len, std.rand.float(random, f32) * space_len);
                const idxs = Self.get_grid_idx(pos);
                _ = try grids[idxs.@"0"][idxs.@"1"].birds.append(Bird.init(pos, null));
            }

            return Self{
                .allocator = allocator,
                .grids = grids,
                .space_len = space_len,
                .grid_len = subgrid_size,
            };
        }

        fn deinit(self: *Self) void {
            for (0..self.grids.len) |i| {
                for (0..self.grids.len) |j| {
                    self.grids[i][j].deinit();
                }
            }
        }

        fn get_grid_idx(pos: Vector2) struct { u32, u32 } {
            const x_idx: u32 = @intFromFloat((pos.x / @as(f32, @floatFromInt(space_len))) * n_subgrids);
            const y_idx: u32 = @intFromFloat((pos.x / @as(f32, @floatFromInt(space_len))) * n_subgrids);
            return .{ x_idx, y_idx };
        }

        fn step(self: *Self) !void {
            // need to do some double buffering here...
            // accumulate updated positions and directions
            //  - use context of birds within same grid, some sort of weighted average
            //  with distance and the three criteria (spacing, alignment, and???)
            // apply updates in another loop, if the updated position moves a bird out of
            // one grid, then take it out and push it into the appropriate one
            // TODO: How do we want to handle behavior at the boundaries? Just clamp the
            // movements like they're hitting some wall?
            for (0..self.grids.len) |i| {
                for (0..self.grids.len) |j| {
                    for (self.grids[i][j].birds.items) |bird| {
                        // TODO: Stuff here...
                        _ = bird;
                    }
                }
            }
        }

        // TODO: Add show_grids option
        fn draw(self: *const Self) void {
            for (0..self.grids.len) |i| {
                for (0..self.grids.len) |j| {
                    for (self.grids[i][j].birds.items) |bird| {
                        bird.draw();
                    }
                }
            }
        }
    };
}

const Grid = struct {
    const Self = @This();

    birds: std.ArrayList(Bird),

    fn init(allocator: std.mem.Allocator) !Self {
        return Self{
            .birds = std.ArrayList(Bird).init(allocator),
        };
    }

    fn deinit(self: *Self) void {
        self.birds.deinit();
    }
};

pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 1200;
    const screenHeight = 1200;
    var gpa = std.heap.GeneralPurposeAllocator(.{ .verbose_log = false }){};
    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    const SIM_SIZE = 1000;
    const GRID_SIZE = 100;
    const N_BIRDS = 100;
    var sim_space = try SimSpace(SIM_SIZE, GRID_SIZE).init(allocator, N_BIRDS);
    defer sim_space.deinit();

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------
        try sim_space.step();

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);

        sim_space.draw();
        //----------------------------------------------------------------------------------
    }
}
