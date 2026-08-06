// substrate.h — правильный заголовок Cydia Substrate

#ifndef SUBSTRATE_H_
#define SUBSTRATE_H_

#include <objc/objc.h>
#include <objc/runtime.h>

#ifdef __cplusplus
extern "C" {
#endif

// =================================================================
// Основные функции Substrate
// =================================================================

/**
 * Перехват Objective-C метода
 */
extern void MSHookMessageEx(Class class_, SEL message, IMP hook, IMP *old);

/**
 * Перехват C функции
 */
extern void MSHookFunction(void *symbol, void *hook, void **old);

/**
 * Освобождение хука
 */
extern void MSHookRelease(void *hook);

/**
 * Получение указателя на функцию
 */
extern IMP MSGetMessageIMP(Class class_, SEL message);

#ifdef __cplusplus
}
#endif

#endif // SUBSTRATE_H_
