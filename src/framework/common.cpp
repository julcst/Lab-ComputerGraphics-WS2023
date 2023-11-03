#include "common.hpp"

#include <fstream>
#include <sstream>
#include <string>

std::string Common::readFile(const std::string& path) {
    std::ifstream stream(path);
    if (!stream.is_open()) throw std::runtime_error("Could not open file: " + path);
    std::stringstream buffer;
    buffer << stream.rdbuf();
    return buffer.str();
}