#include "util.hpp"

#include <imgui.h>
#include <imgui_internal.h>
#include <glm/glm.hpp>
#include <glm/gtc/type_ptr.hpp>

using namespace glm;

void Util::FPSWindow(float frametime, const vec2& resolution) {
    ImGui::SetNextWindowPos(ImVec2(0, 0));
    ImGui::PushStyleColor(ImGuiCol_WindowBg, ImVec4(0.0f, 0.0f, 0.0f, 0.5f));
    ImGui::Begin("Statistics", NULL, ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoInputs | ImGuiWindowFlags_AlwaysAutoResize | ImGuiWindowFlags_NoSavedSettings);
    ImGui::Text("%2.1ffps avg: %2.1ffps %.0fx%.0f", 1.f / frametime, ImGui::GetIO().Framerate, resolution.x, resolution.y);
    ImGui::PopStyleColor();
    ImGui::End();
}

bool Util::sphericalSlider(const char* label, vec3& cart) {
    vec2 sph = vec2(asin(cart.y), atan(cart.x, cart.z));
    ImGui::PushID(label);
    bool changed = false;
    ImGui::PushMultiItemsWidths(2, ImGui::CalcItemWidth());
    ImGui::PushID(0);
    changed |= ImGui::SliderAngle("", &sph.x, -89.0f, 89.0f);
    ImGui::PopItemWidth();
    ImGui::SameLine(0.0f, ImGui::GetStyle().ItemInnerSpacing.x);
    ImGui::PopID();
    ImGui::PushID(1);
    changed |= ImGui::SliderAngle("", &sph.y);
    ImGui::PopItemWidth();
    ImGui::SameLine(0.0f, ImGui::GetStyle().ItemInnerSpacing.x);
    ImGui::PopID();
    ImGui::TextUnformatted(label);
    ImGui::PopID();
    if (changed) cart = vec3(cos(sph.x) * sin(sph.y), sin(sph.x), cos(sph.x) * cos(sph.y));
    return changed;
}

bool Util::angleSlider3(const char* label, vec3& angles) {
    vec3 anglesDeg = degrees(angles);
    bool changed = ImGui::SliderFloat3(label, value_ptr(anglesDeg), -360.0f, 360.0f, "%.0f deg");
    if (changed) angles = radians(anglesDeg);
    return changed;
}