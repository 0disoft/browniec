#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <string.h>

static int read_exact(HANDLE input, uint8_t *out, DWORD length) {
    while (length) {
        DWORD got;
        if (!ReadFile(input, out, length, &got, NULL) || !got) return 0;
        out += got;
        length -= got;
    }
    return 1;
}

int main(void) {
    HANDLE input = GetStdHandle(STD_INPUT_HANDLE), output = GetStdHandle(STD_OUTPUT_HANDLE);
    uint8_t request[78];
    static const uint8_t expected[] = {1,0,3,0,0,0,4,0,0,0,41,0,0,0};
    if (!read_exact(input, request, sizeof(request)) || memcmp(request, "BCA1", 4) ||
        request[4] || request[28] != sizeof(expected) || memcmp(request+64, expected, sizeof(expected)))
        return 11;
    wchar_t mode[2];
    if (GetEnvironmentVariableW(L"BC_ENGINE_ADAPTER_FIXTURE", mode, 2) != 1) return 12;
    if (mode[0] == L'c') {
        wchar_t path[32768];
        DWORD length = GetEnvironmentVariableW(L"BC_ENGINE_ADAPTER_READY", path, ARRAYSIZE(path));
        if (!length || length >= ARRAYSIZE(path)) return 14;
        HANDLE ready = CreateFileW(path, GENERIC_WRITE, FILE_SHARE_READ, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
        if (ready == INVALID_HANDLE_VALUE || !CloseHandle(ready)) return 15;
        Sleep(INFINITE);
        return 16;
    }
    uint8_t reply[76];
    static const uint8_t answer[] = {3,0,0,0,4,0,0,0,42,0,0,0};
    memcpy(reply, request, 64);
    memcpy(reply+64, answer, sizeof(answer));
    reply[4] = 1;
    reply[28] = sizeof(answer);
    if (mode[0] == L'x') reply[8] ^= 1;
    DWORD first = mode[0] == L's' ? 65 : sizeof(reply);
    DWORD done;
    if (!WriteFile(output, reply, first, &done, NULL) || done != first) return 13;
    if (mode[0] == L's') Sleep(INFINITE);
    return 0;
}
