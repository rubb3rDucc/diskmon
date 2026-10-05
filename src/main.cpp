#include <sys/statvfs.h>

#include <chrono>
#include <format>
#include <iostream>
#include <optional>
#include <thread>

namespace {
// returns a nullopt if the file system can't be read.
std::optional<double> disk_usage_percent(const char* path) {

    struct statvfs fs{};
    if (statvfs(path, &fs) != 0) {
        return std::nullopt;
    }

    const double total = static_cast<double>(fs.f_blocks) * static_cast<double>(fs.f_frsize);
    const double avail = static_cast<double>(fs.f_bavail) * static_cast<double>(fs.f_frsize);

    return total > 0.0 ? (total - avail) / total * 100.0 : 0.0;
}
} // namespace

int main() {
    // disk on server
    const char* path = "/";

    // testing on mac
    // const char* path = "/System/Volumes/Data";

    // constexpr double disk_threshold = 1.0;
    constexpr double disk_threshold = 85.0;
    bool paused = false;

    for (;;) {
        if (auto usage = disk_usage_percent(path)) {
            const bool over = *usage >= disk_threshold;
            if (over != paused) {
                std::cout << std::format("{:.1f}% -- {}\n", *usage,
                                         over ? "would pause" : "would resume");
                paused = over;
            }
        } else {
            std::cerr << std::format("cannot read {}\n", path);
        }

        std::this_thread::sleep_for(std::chrono::seconds{5});
    }

    return 0;
}
