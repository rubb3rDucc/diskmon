#include <sys/statvfs.h>

#include <format>
#include <iostream>
#include <chrono>
#include <thread>

int main() {
    const char* path = "/";

    struct statvfs fs {};
    
    if (statvfs(path, &fs) != 0) {
        std::cerr << std::format("cannot read {}\n", path);
        return 1;
    }

    // f_bavail excludes blocks reserved for root, which an unprivileged process
    // cannot use; f_bfree would over-report free space by ~5% on ext4.
    // Cast before dividing -- these fields are unsigned integers.
    const double total = static_cast<double>(fs.f_blocks) * static_cast<double>(fs.f_frsize);
    const double avail = static_cast<double>(fs.f_bavail) * static_cast<double>(fs.f_frsize);
    const double used = total - avail;
    const double percent = (total > 0.0) ? used / total * 100.0 : 0.0;

    for (;;) {
        std::this_thread::sleep_for(std::chrono::seconds{5});
    
        std::cout << std::format("{} is {:.1f}% full ({:.0f} GB used of {:.0f} GB)\n", 
                                path, 
                                percent,
                                used / 1e9, total / 1e9);
    }

    return 0;
}
