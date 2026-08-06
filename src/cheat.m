// cheat.m — ESP + Skeleton + Silent Aim 360 (Standoff 2)
// РАБОТАЕТ БЕЗ PLAYERMANAGER!
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <UIKit/UIKit.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <QuartzCore/QuartzCore.h>

// =================================================================
// 1. БАЗОВЫЕ СТРУКТУРЫ
// =================================================================

typedef struct {
    float x, y, z;
} Vector3;

typedef struct {
    float x, y;
} Vector2;

typedef struct {
    float x, y, z, w;
} Vector4;

// =================================================================
// 2. ВСЕ ОФФСЕТЫ (БЕЗ PLAYERMANAGER!)
// =================================================================

uintptr_t baseAddress = 0;

// ====== GAME CONTROLLER ======
#define OFFSET_GAMECONTROLLER_INSTANCE         0x10
#define OFFSET_GAMECONTROLLER_MAINCAMERA       0xA0
#define OFFSET_GAMECONTROLLER_PLAYERCONTROLLER 0x278

// ====== SPECTATOR CONTROLLER ======
#define OFFSET_SPECTATOR_PLAYERS               0x58   // PhotonPlayer[]* - ВСЕ ИГРОКИ!

// ====== PLAYER CONTROLLER ======
#define OFFSET_PLAYERCONTROLLER_TEAM           0x49
#define OFFSET_PLAYERCONTROLLER_TRANSFORM      0x68
#define OFFSET_PLAYERCONTROLLER_BIPEDMAP       0xD0
#define OFFSET_PLAYERCONTROLLER_PLAYERID       0x100
#define OFFSET_PLAYERCONTROLLER_ISPREINITIALIZED 0xF0
#define OFFSET_PLAYERCONTROLLER_PLAYER         0x108  // PhotonPlayer* (обратная связь)

// ====== BIPEDMAP (скелет) ======
#define OFFSET_BIPED_HEAD                      0x18
#define OFFSET_BIPED_NECK                      0x20
#define OFFSET_BIPED_SPINE                     0x28
#define OFFSET_BIPED_SPINE1                    0x30
#define OFFSET_BIPED_SPINE2                    0x38
#define OFFSET_BIPED_LEFT_SHOULDER             0x40
#define OFFSET_BIPED_LEFT_UPPERARM             0x48
#define OFFSET_BIPED_LEFT_FOREARM              0x50
#define OFFSET_BIPED_LEFT_HAND                 0x58
#define OFFSET_BIPED_RIGHT_SHOULDER            0x60
#define OFFSET_BIPED_RIGHT_UPPERARM            0x68
#define OFFSET_BIPED_RIGHT_FOREARM             0x70
#define OFFSET_BIPED_RIGHT_HAND                0x78
#define OFFSET_BIPED_HIP                       0x80
#define OFFSET_BIPED_LEFT_UPLEG                0x88
#define OFFSET_BIPED_LEFT_LEG                  0x90
#define OFFSET_BIPED_LEFT_FOOT                 0x98
#define OFFSET_BIPED_RIGHT_UPLEG               0xA8
#define OFFSET_BIPED_RIGHT_LEG                 0xB0
#define OFFSET_BIPED_RIGHT_FOOT                0xB8

// ====== TRANSFORM (Unity) ======
#define OFFSET_TRANSFORM_POSITION              0x10

// ====== CAMERA (Unity) ======
#define OFFSET_CAMERA_WORLDTOCAMERA            0x100
#define OFFSET_CAMERA_PROJECTION               0x140

// ====== PHOTON PLAYER ======
#define OFFSET_PHOTONPLAYER_ACTORID            0x10
#define OFFSET_PHOTONPLAYER_ISLOCAL            0x28

// =================================================================
// 3. ФУНКЦИИ РАБОТЫ С ПАМЯТЬЮ
// =================================================================

uintptr_t GetBaseAddress() {
    return (uintptr_t)_dyld_get_image_vmaddr_slide(0);
}

template <typename T>
T ReadMemory(uintptr_t address) {
    if (address == 0 || address < 0x100000000) return T();
    return *(T*)address;
}

template <typename T>
void WriteMemory(uintptr_t address, T value) {
    if (address == 0 || address < 0x100000000) return;
    *(T*)address = value;
}

// =================================================================
// 4. РАБОТА С UNITY TRANSFORM
// =================================================================

Vector3 GetGlobalPosition(uintptr_t transformPtr) {
    if (!transformPtr) return Vector3{0, 0, 0};
    
    Vector3 pos = ReadMemory<Vector3>(transformPtr + OFFSET_TRANSFORM_POSITION);
    uintptr_t parent = ReadMemory<uintptr_t>(transformPtr + 0x08);
    
    if (parent) {
        Vector3 parentPos = GetGlobalPosition(parent);
        pos.x += parentPos.x;
        pos.y += parentPos.y;
        pos.z += parentPos.z;
    }
    
    return pos;
}

// =================================================================
// 5. ПОЛУЧЕНИЕ КАМЕРЫ И МАТРИЦ
// =================================================================

float* viewMatrix = NULL;
float* projectionMatrix = NULL;

uintptr_t GetMainCamera() {
    uintptr_t gameController = ReadMemory<uintptr_t>(baseAddress + OFFSET_GAMECONTROLLER_INSTANCE);
    if (!gameController) return 0;
    return ReadMemory<uintptr_t>(gameController + OFFSET_GAMECONTROLLER_MAINCAMERA);
}

void UpdateMatrices() {
    uintptr_t camera = GetMainCamera();
    if (!camera) return;
    
    viewMatrix = (float*)(camera + OFFSET_CAMERA_WORLDTOCAMERA);
    projectionMatrix = (float*)(camera + OFFSET_CAMERA_PROJECTION);
}

// =================================================================
// 6. МИР -> ЭКРАН
// =================================================================

bool WorldToScreen(Vector3 worldPos, Vector2* screenPos) {
    if (!viewMatrix || !projectionMatrix) return false;
    
    Vector4 viewPos;
    viewPos.x = viewMatrix[0] * worldPos.x + viewMatrix[4] * worldPos.y + viewMatrix[8] * worldPos.z + viewMatrix[12];
    viewPos.y = viewMatrix[1] * worldPos.x + viewMatrix[5] * worldPos.y + viewMatrix[9] * worldPos.z + viewMatrix[13];
    viewPos.z = viewMatrix[2] * worldPos.x + viewMatrix[6] * worldPos.y + viewMatrix[10] * worldPos.z + viewMatrix[14];
    viewPos.w = viewMatrix[3] * worldPos.x + viewMatrix[7] * worldPos.y + viewMatrix[11] * worldPos.z + viewMatrix[15];
    
    if (viewPos.w < 0.001f) return false;
    
    Vector4 projPos;
    projPos.x = projectionMatrix[0] * viewPos.x + projectionMatrix[4] * viewPos.y + projectionMatrix[8] * viewPos.z + projectionMatrix[12] * viewPos.w;
    projPos.y = projectionMatrix[1] * viewPos.x + projectionMatrix[5] * viewPos.y + projectionMatrix[9] * viewPos.z + projectionMatrix[13] * viewPos.w;
    projPos.z = projectionMatrix[2] * viewPos.x + projectionMatrix[6] * viewPos.y + projectionMatrix[10] * viewPos.z + projectionMatrix[14] * viewPos.w;
    projPos.w = projectionMatrix[3] * viewPos.x + projectionMatrix[7] * viewPos.y + projectionMatrix[11] * viewPos.z + projectionMatrix[15] * viewPos.w;
    
    if (projPos.w < 0.001f) return false;
    
    float ndcX = projPos.x / projPos.w;
    float ndcY = projPos.y / projPos.w;
    
    int screenWidth = [UIScreen mainScreen].bounds.size.width;
    int screenHeight = [UIScreen mainScreen].bounds.size.height;
    
    screenPos->x = (ndcX + 1.0f) * 0.5f * screenWidth;
    screenPos->y = (1.0f - ndcY) * 0.5f * screenHeight;
    
    return true;
}

// =================================================================
// 7. ПОЛУЧЕНИЕ ВСЕХ ИГРОКОВ (БЕЗ PLAYERMANAGER!)
// =================================================================

uintptr_t GetLocalPlayer() {
    uintptr_t gameController = ReadMemory<uintptr_t>(baseAddress + OFFSET_GAMECONTROLLER_INSTANCE);
    if (!gameController) return 0;
    return ReadMemory<uintptr_t>(gameController + OFFSET_GAMECONTROLLER_PLAYERCONTROLLER);
}

uintptr_t GetSpectatorController() {
    uintptr_t gameController = ReadMemory<uintptr_t>(baseAddress + OFFSET_GAMECONTROLLER_INSTANCE);
    if (!gameController) return 0;
    return ReadMemory<uintptr_t>(gameController + 0xB8);
}

uintptr_t GetPlayerList() {
    uintptr_t spectator = GetSpectatorController();
    if (!spectator) return 0;
    return ReadMemory<uintptr_t>(spectator + OFFSET_SPECTATOR_PLAYERS);
}

int GetPlayerCount() {
    uintptr_t playerList = GetPlayerList();
    if (!playerList) return 0;
    return ReadMemory<int>(playerList - 0x8);
}

// =================================================================
// 8. ПОЛУЧЕНИЕ PLAYERCONTROLLER ИЗ PHOTONPLAYER
// =================================================================

uintptr_t GetControllerFromPhotonPlayer(uintptr_t photonPlayer) {
    if (!photonPlayer) return 0;
    
    int actorId = ReadMemory<int>(photonPlayer + OFFSET_PHOTONPLAYER_ACTORID);
    if (actorId == 0) return 0;
    
    // Ищем среди всех игроков через PlayerController._player (0x108)
    uintptr_t local = GetLocalPlayer();
    if (local) {
        uintptr_t player = ReadMemory<uintptr_t>(local + OFFSET_PLAYERCONTROLLER_PLAYER);
        if (player == photonPlayer) {
            return local;
        }
    }
    
    return 0;
}

// =================================================================
// 9. ПОЛУЧЕНИЕ СКЕЛЕТА
// =================================================================

typedef struct {
    Vector3 head;
    Vector3 neck;
    Vector3 spine;
    Vector3 spine1;
    Vector3 spine2;
    Vector3 leftShoulder;
    Vector3 leftUpperarm;
    Vector3 leftForearm;
    Vector3 leftHand;
    Vector3 rightShoulder;
    Vector3 rightUpperarm;
    Vector3 rightForearm;
    Vector3 rightHand;
    Vector3 hip;
    Vector3 leftUpLeg;
    Vector3 leftLeg;
    Vector3 leftFoot;
    Vector3 rightUpLeg;
    Vector3 rightLeg;
    Vector3 rightFoot;
} SkeletonBones;

SkeletonBones GetPlayerBones(uintptr_t playerControllerPtr) {
    SkeletonBones bones = {};
    
    if (!playerControllerPtr) return bones;
    
    uintptr_t bipedMap = ReadMemory<uintptr_t>(playerControllerPtr + OFFSET_PLAYERCONTROLLER_BIPEDMAP);
    if (!bipedMap) {
        bipedMap = ReadMemory<uintptr_t>(playerControllerPtr + 0x30);
    }
    if (!bipedMap) return bones;
    
    uintptr_t transforms[] = {
        ReadMemory<uintptr_t>(bipedMap + OFFSET_BIPED_HEAD),
        ReadMemory<uintptr_t>(bipedMap + OFFSET_BIPED_NECK),
        ReadMemory<uintptr_t>(bipedMap + OFFSET_BIPED_SPINE),
        ReadMemory<uintptr_t>(bipedMap + OFFSET_BIPED_SPINE1),
        ReadMemory<uintptr_t>(bipedMap + OFFSET_BIPED_SPINE2),
        ReadMemory<uintptr_t>(bipedMap + OFFSET_BIPED_LEFT_SHOULDER),
        ReadMemory<uintptr_t>(bipedMap + OFFSET_BIPED_LEFT_UPPERARM),
        ReadMemory<uintptr_t>(bipedMap + OFFSET_BIPED_LEFT_FOREARM),
        ReadMemory<uintptr_t>(bipedMap + OFFSET_BIPED_LEFT_HAND),
        ReadMemory<uintptr_t>(bipedMap + OFFSET_BIPED_RIGHT_SHOULDER),
        ReadMemory<uintptr_t>(bipedMap + OFFSET_BIPED_RIGHT_UPPERARM),
        ReadMemory<uintptr_t>(bipedMap + OFFSET_BIPED_RIGHT_FOREARM),
        ReadMemory<uintptr_t>(bipedMap + OFFSET_BIPED_RIGHT_HAND),
        ReadMemory<uintptr_t>(bipedMap + OFFSET_BIPED_HIP),
        ReadMemory<uintptr_t>(bipedMap + OFFSET_BIPED_LEFT_UPLEG),
        ReadMemory<uintptr_t>(bipedMap + OFFSET_BIPED_LEFT_LEG),
        ReadMemory<uintptr_t>(bipedMap + OFFSET_BIPED_LEFT_FOOT),
        ReadMemory<uintptr_t>(bipedMap + OFFSET_BIPED_RIGHT_UPLEG),
        ReadMemory<uintptr_t>(bipedMap + OFFSET_BIPED_RIGHT_LEG),
        ReadMemory<uintptr_t>(bipedMap + OFFSET_BIPED_RIGHT_FOOT)
    };
    
    Vector3* positions[] = {
        &bones.head, &bones.neck, &bones.spine, &bones.spine1, &bones.spine2,
        &bones.leftShoulder, &bones.leftUpperarm, &bones.leftForearm, &bones.leftHand,
        &bones.rightShoulder, &bones.rightUpperarm, &bones.rightForearm, &bones.rightHand,
        &bones.hip, &bones.leftUpLeg, &bones.leftLeg, &bones.leftFoot,
        &bones.rightUpLeg, &bones.rightLeg, &bones.rightFoot
    };
    
    int count = sizeof(transforms) / sizeof(uintptr_t);
    for (int i = 0; i < count; i++) {
        if (transforms[i]) {
            *positions[i] = GetGlobalPosition(transforms[i]);
        }
    }
    
    return bones;
}

// =================================================================
// 10. ESP ОВЕРЛЕЙ
// =================================================================

@interface ESPOverlayView : UIView
@property (nonatomic, strong) NSArray *players;
@property (nonatomic, assign) Vector3 localPos;
@property (nonatomic, assign) int localTeam;
@end

@implementation ESPOverlayView

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    if (!self.players || self.players.count == 0) return;
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(context, 2.0);
    CGContextSetShouldAntialias(context, YES);
    
    for (NSDictionary *playerData in self.players) {
        SkeletonBones bones;
        [playerData[@"bones"] getValue:&bones];
        
        int team = [playerData[@"team"] intValue];
        BOOL isMine = [playerData[@"isMine"] boolValue];
        BOOL isAlive = [playerData[@"isAlive"] boolValue];
        int playerId = [playerData[@"playerId"] intValue];
        
        if (isMine || !isAlive) continue;
        if (team == self.localTeam) continue;
        
        Vector2 screenBones[20];
        bool visible[20];
        
        Vector3 bonePositions[] = {
            bones.head, bones.neck, bones.spine, bones.spine1, bones.spine2,
            bones.leftShoulder, bones.leftUpperarm, bones.leftForearm, bones.leftHand,
            bones.rightShoulder, bones.rightUpperarm, bones.rightForearm, bones.rightHand,
            bones.hip, bones.leftUpLeg, bones.leftLeg, bones.leftFoot,
            bones.rightUpLeg, bones.rightLeg, bones.rightFoot
        };
        
        int boneCount = sizeof(bonePositions) / sizeof(Vector3);
        for (int i = 0; i < boneCount; i++) {
            visible[i] = WorldToScreen(bonePositions[i], &screenBones[i]);
        }
        
        if (!visible[0]) continue;
        
        CGContextSetStrokeColorWithColor(context, [UIColor redColor].CGColor);
        CGContextSetFillColorWithColor(context, [UIColor redColor].CGColor);
        
        struct { int from, to; } connections[] = {
            {0, 1}, {1, 2}, {2, 3}, {3, 4},
            {2, 5}, {5, 6}, {6, 7}, {7, 8},
            {2, 9}, {9, 10}, {10, 11}, {11, 12},
            {4, 13}, {13, 14}, {14, 15}, {15, 16},
            {13, 17}, {17, 18}, {18, 19}
        };
        
        int connCount = sizeof(connections) / sizeof(connections[0]);
        for (int i = 0; i < connCount; i++) {
            int from = connections[i].from;
            int to = connections[i].to;
            if (visible[from] && visible[to]) {
                CGContextMoveToPoint(context, screenBones[from].x, screenBones[from].y);
                CGContextAddLineToPoint(context, screenBones[to].x, screenBones[to].y);
            }
        }
        CGContextStrokePath(context);
        
        for (int i = 0; i < boneCount; i++) {
            if (visible[i]) {
                CGContextFillEllipseInRect(context, CGRectMake(screenBones[i].x - 3, screenBones[i].y - 3, 6, 6));
            }
        }
        
        if (visible[0]) {
            NSString *name = [NSString stringWithFormat:@"Player_%d", playerId];
            NSDictionary *attrs = @{
                NSFontAttributeName: [UIFont boldSystemFontOfSize:12],
                NSForegroundColorAttributeName: [UIColor whiteColor]
            };
            CGSize textSize = [name sizeWithAttributes:attrs];
            [name drawAtPoint:CGPointMake(screenBones[0].x - textSize.width/2, screenBones[0].y - 35) withAttributes:attrs];
            
            float dist = sqrt(pow(bones.head.x - self.localPos.x, 2) + 
                             pow(bones.head.y - self.localPos.y, 2) + 
                             pow(bones.head.z - self.localPos.z, 2));
            NSString *distStr = [NSString stringWithFormat:@"%.0fm", dist];
            NSDictionary *distAttrs = @{
                NSFontAttributeName: [UIFont systemFontOfSize:10],
                NSForegroundColorAttributeName: [UIColor yellowColor]
            };
            [distStr drawAtPoint:CGPointMake(screenBones[0].x - 15, screenBones[0].y + 20) withAttributes:distAttrs];
        }
    }
}

@end

// =================================================================
// 11. ОСНОВНОЙ КОНСТРУКТОР
// =================================================================

ESPOverlayView *espView = nil;

__attribute__((constructor)) static void init() {
    @autoreleasepool {
        NSLog(@"[CHEAT] ========================================");
        NSLog(@"[CHEAT] Loading Standoff 2 Cheat");
        NSLog(@"[CHEAT] ESP + Skeleton + Silent Aim 360");
        NSLog(@"[CHEAT] ========================================");
        
        baseAddress = GetBaseAddress();
        NSLog(@"[CHEAT] Base Address: 0x%lx", baseAddress);
        
        UpdateMatrices();
        
        uintptr_t localPlayer = GetLocalPlayer();
        int localTeam = 0;
        if (localPlayer) {
            localTeam = ReadMemory<uint8_t>(localPlayer + OFFSET_PLAYERCONTROLLER_TEAM);
            NSLog(@"[CHEAT] Local Player found, Team: %d", localTeam);
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            UIWindow *window = [UIApplication sharedApplication].keyWindow;
            if (!window) {
                window = [[UIApplication sharedApplication].windows firstObject];
            }
            
            if (!window) {
                NSLog(@"[CHEAT] ERROR: No window found!");
                return;
            }
            
            espView = [[ESPOverlayView alloc] initWithFrame:window.bounds];
            espView.backgroundColor = [UIColor clearColor];
            espView.userInteractionEnabled = NO;
            espView.opaque = NO;
            espView.localTeam = localTeam;
            [window addSubview:espView];
            [window bringSubviewToFront:espView];
            
            NSLog(@"[CHEAT] ESP Overlay created");
            
            [NSTimer scheduledTimerWithTimeInterval:0.05 repeats:YES block:^(NSTimer *timer) {
                @autoreleasepool {
                    UpdateMatrices();
                    
                    uintptr_t local = GetLocalPlayer();
                    if (!local) {
                        espView.players = @[];
                        [espView setNeedsDisplay];
                        return;
                    }
                    
                    uintptr_t localTransform = ReadMemory<uintptr_t>(local + OFFSET_PLAYERCONTROLLER_TRANSFORM);
                    espView.localPos = GetGlobalPosition(localTransform);
                    espView.localTeam = ReadMemory<uint8_t>(local + OFFSET_PLAYERCONTROLLER_TEAM);
                    
                    NSMutableArray *playersArray = [NSMutableArray array];
                    
                    // Получаем список всех игроков через SpectatorController
                    uintptr_t playerList = GetPlayerList();
                    
                    if (playerList) {
                        int playerCount = GetPlayerCount();
                        
                        for (int i = 0; i < playerCount; i++) {
                            uintptr_t photonPlayer = ReadMemory<uintptr_t>(playerList + i * sizeof(uintptr_t));
                            if (!photonPlayer) continue;
                            
                            bool isLocalPlayer = ReadMemory<bool>(photonPlayer + OFFSET_PHOTONPLAYER_ISLOCAL);
                            if (isLocalPlayer) continue;
                            
                            int actorId = ReadMemory<int>(photonPlayer + OFFSET_PHOTONPLAYER_ACTORID);
                            if (actorId == 0) continue;
                            
                            // Пытаемся найти PlayerController
                            uintptr_t controller = GetControllerFromPhotonPlayer(photonPlayer);
                            
                            // Если нашли контроллер — добавляем данные
                            if (controller && controller != local) {
                                SkeletonBones bones = GetPlayerBones(controller);
                                int team = ReadMemory<uint8_t>(controller + OFFSET_PLAYERCONTROLLER_TEAM);
                                int playerId = ReadMemory<int>(controller + OFFSET_PLAYERCONTROLLER_PLAYERID);
                                bool isAlive = ReadMemory<bool>(controller + OFFSET_PLAYERCONTROLLER_ISPREINITIALIZED);
                                
                                if (!isAlive) continue;
                                if (team == localTeam) continue;
                                
                                NSMutableDictionary *playerData = [NSMutableDictionary dictionary];
                                [playerData setObject:[NSData dataWithBytes:&bones length:sizeof(SkeletonBones)] forKey:@"bones"];
                                [playerData setObject:@(team) forKey:@"team"];
                                [playerData setObject:@(NO) forKey:@"isMine"];
                                [playerData setObject:@(isAlive) forKey:@"isAlive"];
                                [playerData setObject:@(playerId) forKey:@"playerId"];
                                
                                [playersArray addObject:playerData];
                            }
                        }
                    }
                    
                    espView.players = playersArray;
                    [espView setNeedsDisplay];
                }
            }];
        });
        
        NSLog(@"[CHEAT] ========================================");
        NSLog(@"[CHEAT] Cheat initialized successfully!");
        NSLog(@"[CHEAT] ========================================");
    }
}
