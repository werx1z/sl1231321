// substrate.h — правильный заголовочный файл для Cydia Substrate
// Источник: официальный SDK

#ifndef SUBSTRATE_H
#define SUBSTRATE_H

#include <objc/objc.h>
#include <objc/runtime.h>

#ifdef __cplusplus
extern "C" {
#endif

// =================================================================
// Основные функции Substrate
// =================================================================

// Создание хука на Objective-C метод
extern void MSHookMessageEx(Class _class, SEL message, IMP hook, IMP *old);

// Создание хука на C функцию
extern void MSHookFunction(void *symbol, void *hook, void **old);

// Освобождение памяти Substrate
extern void MSHookRelease(void *hook);

// Получение информации о вызове
extern IMP MSGetMessageIMP(Class _class, SEL message);

// Перехват Objective-C метода с возвращаемым значением
#define MSHookMessage(CLASS, SELECTOR, REPLACE, RESULT) \
    MSHookMessageEx(CLASS, SELECTOR, (IMP)REPLACE, (IMP*)&RESULT)

// =================================================================
// Вспомогательные макросы
// =================================================================

// Объявление метода-заглушки
#define MSHookMessageEx(CLASS, SELECTOR, REPLACE, RESULT) \
    MSHookMessageEx(CLASS, SELECTOR, (IMP)REPLACE, (IMP*)&RESULT)

// =================================================================
// Структура для хранения информации о хуке
// =================================================================

typedef struct {
    IMP original;
    IMP replacement;
    SEL selector;
    Class class;
} MSHookInfo;

// =================================================================
// Дополнительные утилиты
// =================================================================

// Получение указателя на функцию по имени
extern void *MSFindSymbol(void *handle, const char *symbol);

// =================================================================
// Для совместимости с другими версиями
// =================================================================

#ifndef MSHookMessageEx
#define MSHookMessageEx MSHookMessageEx
#endif

#ifdef __cplusplus
}
#endif

#endif // SUBSTRATE_H
