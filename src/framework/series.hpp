#pragma once

#include <array>
#include <type_traits>

/**
 * Implements a circular buffer that holds a fixed number of measurements and continously computes the average and the sum
 */
template <typename T, size_t N>
class Series {
   public:
    T sum = 0.0f;
    T avg = 0.0f;

    void push(T measurement) {
        measurements[head] = measurement; // store new measurement
        head = (head + 1) % N; // increment head and wrap around if necessary
        sum = sum + measurement; // add new measurement to sum
        if (count < N) {
            count++;
        } else {
            sum = sum - measurements[head]; // remove oldest measurement from sum
        }
        avg = sum / count;
    }

    T latest() const {
        return measurements[(head + N - 1) % N];
    }

   private:
    std::array<T, N> measurements;
    size_t head = 0;
    size_t count = 0;
};