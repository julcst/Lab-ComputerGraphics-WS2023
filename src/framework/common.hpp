#pragma once

#include <string>

namespace Common {

std::string readFile(const std::string& filename);
void writeToFile(const std::string& content, const std::string& path);

}