// cheat.m — ESP + Skeleton + Silent Aim 360 (Standoff 2)
// АВТОМАТИЧЕСКИЙ ПОИСК GAMECONTROLLER!
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
// 2. ОФФСЕТЫ (КРОМЕ GAMECONTROLLER — БУДЕТ НАЙДЕН АВТОМАТИЧЕСКИ!)
// =================================================================

uintptr_t baseAddress = 0;
uintptr_t gameControllerOffset = 0; // Будет найден автоматически

// ====== GAME CONTROLLER (будет найден) ======
#define OFFSET_GAMECONTROLLER_MAINCAMERA       0xA0
#define OFFSET_GAMECONTROLLER_PLAYERCONTROLLER 0x280

// ====== SPECTATOR CONTROLLER ======
#define OFFSET_SPECTATOR_PLAYERS               0x58

// ====== PLAYER CONTROLLER ======
#define OFFSET_PLAYERCONTROLLER_TEAM           0x49
#define OFFSET_PLAYERCONTROLLER_TRANSFORM      0x68
#define OFFSET_PLAYERCONTROLLER_BIPEDMAP       0xD0
#define OFFSET_PLAYERCONTROLLER_PLAYERID       0x100
#define OFFSET_PLAYERCONTROLLER_ISPREINITIALIZED 0xF0
#define OFFSET_PLAYERCONTROLLER_PLAYER         0x108

// ====== BIPEDMAP ======
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

// ====== TRANSFORM ======
#define OFFSET_TRANSFORM_POSITION              0x10

// ====== CAMERA ======
#define OFFSET_CAMERA_WORLDTOCAMERA            0xE0
#define OFFSET_CAMERA_PROJECTION               0x120

// ====== PHOTON PLAYER ======
#define OFFSET_PHOTONPLAYER_ACTORID            0x10
#define OFFSET_PHOTONPLAYER_ISLOCAL            0x28

// =================================================================
// 3. ФУНКЦИЯ ДЛЯ ЗАПИСИ ЛОГОВ
// =================================================================

void WriteLog(NSString *message) {
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *logPath = [docPath stringByAppendingPathComponent:@"cheat_log.txt"];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    NSString *logEntry = [NSString stringWithFormat:@"[%@] %@\n", timestamp, message];
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:logPath];
    if (fileHandle) {
        [fileHandle seekToEndOfFile];
        [fileHandle writeData:[logEntry dataUsingEncoding:NSUTF8StringEncoding]];
        [fileHandle closeFile];
    } else {
        [logEntry writeToFile:logPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

// =================================================================
// 4. ФУНКЦИИ РАБОТЫ С ПАМЯТЬЮ
// =================================================================

uintptr_t GetBaseAddress() {
    return (uintptr_t)_dyld_get_image_vmaddr_slide(0);
}

uint8_t ReadUInt8(uintptr_t address) {
    if (address == 0 || address < 0x100000000) return 0;
    return *(uint8_t*)address;
}

uint32_t ReadUInt32(uintptr_t address) {
    if (address == 0 || address < 0x100000000) return 0;
    return *(uint32_t*)address;
}

uintptr_t ReadPtr(uintptr_t address) {
    if (address == 0 || address < 0x100000000) return 0;
    return *(uintptr_t*)address;
}

float ReadFloat(uintptr_t address) {
    if (address == 0 || address < 0x100000000) return 0;
    return *(float*)address;
}

Vector3 ReadVector3(uintptr_t address) {
    Vector3 v = {0, 0, 0};
    if (address == 0 || address < 0x100000000) return v;
    v.x = *(float*)(address);
    v.y = *(float*)(address + 4);
    v.z = *(float*)(address + 8);
    return v;
}

void WriteUInt32(uintptr_t address, uint32_t value) {
    if (address == 0 || address < 0x100000000) return;
    *(uint32_t*)address = value;
}

// =================================================================
// 5. АВТОМАТИЧЕСКИЙ ПОИСК GAMECONTROLLER!
// =================================================================

uintptr_t FindGameController() {
    WriteLog(@"🔍 SCANNING for GameController...");
    
    // Перебираем все возможные оффсеты от 0x08 до 0x50
    uintptr_t possibleOffsets[] = {
        0x08, 0x10, 0x18, 0x20, 0x28, 0x30, 0x38, 0x40, 0x48, 0x50,
        0x58, 0x60, 0x68, 0x70, 0x78, 0x80, 0x88, 0x90, 0x98, 0xA0
    };
    
    for (int i = 0; i < 20; i++) {
        uintptr_t offset = possibleOffsets[i];
        uintptr_t gc = ReadPtr(baseAddress + offset);
        
        if (gc && gc > 0x100000000) {
            // Проверяем, есть ли камера по оффсету 0xA0
            uintptr_t camera = ReadPtr(gc + OFFSET_GAMECONTROLLER_MAINCAMERA);
            if (camera && camera > 0x100000000) {
                // Проверяем, есть ли локальный игрок по оффсету 0x280
                uintptr_t player = ReadPtr(gc + OFFSET_GAMECONTROLLER_PLAYERCONTROLLER);
                if (player && player > 0x100000000) {
                    WriteLog([NSString stringWithFormat:@"✅ FOUND GameController at offset 0x%lx!", offset]);
                    WriteLog([NSString stringWithFormat:@"   GameController: 0x%lx", gc]);
                    WriteLog([NSString stringWithFormat:@"   Camera: 0x%lx", camera]);
                    WriteLog([NSString stringWithFormat:@"   LocalPlayer: 0x%lx", player]);
                    gameControllerOffset = offset;
                    return gc;
                }
            }
        }
    }
    
    WriteLog(@"❌ GameController NOT found in any offset!");
    return 0;
}

// =================================================================
// 6. РАБОТА С UNITY TRANSFORM
// =================================================================

Vector3 GetGlobalPosition(uintptr_t transformPtr) {
    Vector3 zero = {0, 0, 0};
    if (!transformPtr) return zero;
    
    Vector3 pos = ReadVector3(transformPtr + OFFSET_TRANSFORM_POSITION);
    uintptr_t parent = ReadPtr(transformPtr + 0x08);
    
    if (parent) {
        Vector3 parentPos = GetGlobalPosition(parent);
        pos.x += parentPos.x;
        pos.y += parentPos.y;
        pos.z += parentPos.z;
    }
    
    return pos;
}

// =================================================================
// 7. ПОЛУЧЕНИЕ КАМЕРЫ И МАТРИЦ
// =================================================================

float* viewMatrix = NULL;
float* projectionMatrix = NULL;
uintptr_t gameController = 0;

uintptr_t GetMainCamera() {
    if (!gameController) return 0;
    return ReadPtr(gameController + OFFSET_GAMECONTROLLER_MAINCAMERA);
}

void UpdateMatrices() {
    uintptr_t camera = GetMainCamera();
    if (!camera) return;
    
    viewMatrix = (float*)(camera + OFFSET_CAMERA_WORLDTOCAMERA);
    projectionMatrix = (float*)(camera + OFFSET_CAMERA_PROJECTION);
}

// =================================================================
// 8. МИР -> ЭКРАН
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
    
    int screenWidth = (int)[UIScreen mainScreen].bounds.size.width;
    int screenHeight = (int)[UIScreen mainScreen].bounds.size.height;
    
    screenPos->x = (ndcX + 1.0f) * 0.5f * screenWidth;
    screenPos->y = (1.0f - ndcY) * 0.5f * screenHeight;
    
    return true;
}

// =================================================================
// 9. ПОЛУЧЕНИЕ ИГРОКОВ
// =================================================================

uintptr_t GetLocalPlayer() {
    if (!gameController) return 0;
    return ReadPtr(gameController + OFFSET_GAMECONTROLLER_PLAYERCONTROLLER);
}

uintptr_t GetSpectatorController() {
    if (!gameController) return 0;
    return ReadPtr(gameController + 0xB8);
}

uintptr_t GetPlayerList() {
    uintptr_t spectator = GetSpectatorController();
    if (!spectator) return 0;
    return ReadPtr(spectator + OFFSET_SPECTATOR_PLAYERS);
}

int GetPlayerCount() {
    uintptr_t playerList = GetPlayerList();
    if (!playerList) return 0;
    return (int)ReadUInt32(playerList - 0x8);
}

// =================================================================
// 10. ПОЛУЧЕНИЕ PLAYERCONTROLLER ИЗ PHOTONPLAYER
// =================================================================

uintptr_t GetControllerFromPhotonPlayer(uintptr_t photonPlayer) {
    if (!photonPlayer) return 0;
    
    int actorId = (int)ReadUInt32(photonPlayer + OFFSET_PHOTONPLAYER_ACTORID);
    if (actorId == 0) return 0;
    
    uintptr_t local = GetLocalPlayer();
    if (local) {
        uintptr_t player = ReadPtr(local + OFFSET_PLAYERCONTROLLER_PLAYER);
        if (player == photonPlayer) {
            return local;
        }
    }
    
    return 0;
}

// =================================================================
// 11. ПОЛУЧЕНИЕ СКЕЛЕТА
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
    
    uintptr_t bipedMap = ReadPtr(playerControllerPtr + OFFSET_PLAYERCONTROLLER_BIPEDMAP);
    if (!bipedMap) {
        bipedMap = ReadPtr(playerControllerPtr + 0x30);
    }
    if (!bipedMap) return bones;
    
    uintptr_t transforms[20];
    transforms[0] = ReadPtr(bipedMap + OFFSET_BIPED_HEAD);
    transforms[1] = ReadPtr(bipedMap + OFFSET_BIPED_NECK);
    transforms[2] = ReadPtr(bipedMap + OFFSET_BIPED_SPINE);
    transforms[3] = ReadPtr(bipedMap + OFFSET_BIPED_SPINE1);
    transforms[4] = ReadPtr(bipedMap + OFFSET_BIPED_SPINE2);
    transforms[5] = ReadPtr(bipedMap + OFFSET_BIPED_LEFT_SHOULDER);
    transforms[6] = ReadPtr(bipedMap + OFFSET_BIPED_LEFT_UPPERARM);
    transforms[7] = ReadPtr(bipedMap + OFFSET_BIPED_LEFT_FOREARM);
    transforms[8] = ReadPtr(bipedMap + OFFSET_BIPED_LEFT_HAND);
    transforms[9] = ReadPtr(bipedMap + OFFSET_BIPED_RIGHT_SHOULDER);
    transforms[10] = ReadPtr(bipedMap + OFFSET_BIPED_RIGHT_UPPERARM);
    transforms[11] = ReadPtr(bipedMap + OFFSET_BIPED_RIGHT_FOREARM);
    transforms[12] = ReadPtr(bipedMap + OFFSET_BIPED_RIGHT_HAND);
    transforms[13] = ReadPtr(bipedMap + OFFSET_BIPED_HIP);
    transforms[14] = ReadPtr(bipedMap + OFFSET_BIPED_LEFT_UPLEG);
    transforms[15] = ReadPtr(bipedMap + OFFSET_BIPED_LEFT_LEG);
    transforms[16] = ReadPtr(bipedMap + OFFSET_BIPED_LEFT_FOOT);
    transforms[17] = ReadPtr(bipedMap + OFFSET_BIPED_RIGHT_UPLEG);
    transforms[18] = ReadPtr(bipedMap + OFFSET_BIPED_RIGHT_LEG);
    transforms[19] = ReadPtr(bipedMap + OFFSET_BIPED_RIGHT_FOOT);
    
    Vector3* positions[20];
    positions[0] = &bones.head;
    positions[1] = &bones.neck;
    positions[2] = &bones.spine;
    positions[3] = &bones.spine1;
    positions[4] = &bones.spine2;
    positions[5] = &bones.leftShoulder;
    positions[6] = &bones.leftUpperarm;
    positions[7] = &bones.leftForearm;
    positions[8] = &bones.leftHand;
    positions[9] = &bones.rightShoulder;
    positions[10] = &bones.rightUpperarm;
    positions[11] = &bones.rightForearm;
    positions[12] = &bones.rightHand;
    positions[13] = &bones.hip;
    positions[14] = &bones.leftUpLeg;
    positions[15] = &bones.leftLeg;
    positions[16] = &bones.leftFoot;
    positions[17] = &bones.rightUpLeg;
    positions[18] = &bones.rightLeg;
    positions[19] = &bones.rightFoot;
    
    for (int i = 0; i < 20; i++) {
        if (transforms[i]) {
            *positions[i] = GetGlobalPosition(transforms[i]);
        }
    }
    
    return bones;
}

// =================================================================
// 12. ESP ОВЕРЛЕЙ
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
        
        int team = [[playerData objectForKey:@"team"] intValue];
        BOOL isMine = [[playerData objectForKey:@"isMine"] boolValue];
        BOOL isAlive = [[playerData objectForKey:@"isAlive"] boolValue];
        int playerId = [[playerData objectForKey:@"playerId"] intValue];
        
        if (isMine || !isAlive) continue;
        if (team == self.localTeam) continue;
        
        Vector2 screenBones[20];
        bool visible[20];
        
        Vector3 bonePositions[20];
        bonePositions[0] = bones.head;
        bonePositions[1] = bones.neck;
        bonePositions[2] = bones.spine;
        bonePositions[3] = bones.spine1;
        bonePositions[4] = bones.spine2;
        bonePositions[5] = bones.leftShoulder;
        bonePositions[6] = bones.leftUpperarm;
        bonePositions[7] = bones.leftForearm;
        bonePositions[8] = bones.leftHand;
        bonePositions[9] = bones.rightShoulder;
        bonePositions[10] = bones.rightUpperarm;
        bonePositions[11] = bones.rightForearm;
        bonePositions[12] = bones.rightHand;
        bonePositions[13] = bones.hip;
        bonePositions[14] = bones.leftUpLeg;
        bonePositions[15] = bones.leftLeg;
        bonePositions[16] = bones.leftFoot;
        bonePositions[17] = bones.rightUpLeg;
        bonePositions[18] = bones.rightLeg;
        bonePositions[19] = bones.rightFoot;
        
        int boneCount = 20;
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
// 13. ТОЧКА ВХОДА С АВТОМАТИЧЕСКИМ ПОИСКОМ
// =================================================================

ESPOverlayView *espView = nil;

__attribute__((constructor)) static void init() {
    @autoreleasepool {
        WriteLog(@"=== CHEAT INIT STARTED ===");
        
        baseAddress = GetBaseAddress();
        WriteLog([NSString stringWithFormat:@"Base Address: 0x%lx", baseAddress]);
        
        // 🔍 АВТОМАТИЧЕСКИЙ ПОИСК GAMECONTROLLER!
        gameController = FindGameController();
        
        if (!gameController) {
            WriteLog(@"❌ CRITICAL: GameController not found! Cheat will not work.");
            return;
        }
        
        WriteLog(@"✅ GameController found successfully!");
        
        // Обновляем матрицы
        UpdateMatrices();
        
        // Проверяем камеру
        uintptr_t camera = GetMainCamera();
        if (!camera) {
            WriteLog(@"❌ ERROR: Camera is NULL!");
            return;
        }
        WriteLog([NSString stringWithFormat:@"Camera: 0x%lx", camera]);
        
        // Проверяем локального игрока
        uintptr_t localPlayer = GetLocalPlayer();
        if (!localPlayer) {
            WriteLog(@"❌ ERROR: LocalPlayer is NULL!");
            return;
        }
        WriteLog([NSString stringWithFormat:@"LocalPlayer: 0x%lx", localPlayer]);
        
        // Проверяем матрицы
        if (!viewMatrix || !projectionMatrix) {
            WriteLog(@"❌ ERROR: Matrices are NULL!");
            return;
        }
        WriteLog(@"✅ Matrices found!");
        
        // Проверяем список игроков
        uintptr_t spectator = GetSpectatorController();
        if (spectator) {
            WriteLog([NSString stringWithFormat:@"SpectatorController: 0x%lx", spectator]);
            uintptr_t playerList = GetPlayerList();
            if (playerList) {
                int count = GetPlayerCount();
                WriteLog([NSString stringWithFormat:@"✅ Player count: %d", count]);
            } else {
                WriteLog(@"⚠️ PlayerList is NULL (might be in menu)");
            }
        } else {
            WriteLog(@"⚠️ SpectatorController is NULL (might be in menu)");
        }
        
        // Создаём ESP
        dispatch_async(dispatch_get_main_queue(), ^{
            WriteLog(@"Creating ESP overlay...");
            UIWindow *window = [UIApplication sharedApplication].keyWindow;
            if (!window) {
                window = [[UIApplication sharedApplication].windows firstObject];
            }
            
            if (!window) {
                WriteLog(@"❌ ERROR: No window found!");
                return;
            }
            
            int localTeam = (int)ReadUInt8(localPlayer + OFFSET_PLAYERCONTROLLER_TEAM);
            WriteLog([NSString stringWithFormat:@"Local Team: %d", localTeam]);
            
            espView = [[ESPOverlayView alloc] initWithFrame:window.bounds];
            espView.backgroundColor = [UIColor clearColor];
            espView.userInteractionEnabled = NO;
            espView.opaque = NO;
            espView.localTeam = localTeam;
            [window addSubview:espView];
            [window bringSubviewToFront:espView];
            WriteLog(@"✅ ESP Overlay created!");
            
            // Таймер для обновления
            [NSTimer scheduledTimerWithTimeInterval:0.05 repeats:YES block:^(NSTimer *timer) {
                @autoreleasepool {
                    UpdateMatrices();
                    uintptr_t local = GetLocalPlayer();
                    if (!local) {
                        espView.players = @[];
                        [espView setNeedsDisplay];
                        return;
                    }
                    
                    uintptr_t localTransform = ReadPtr(local + OFFSET_PLAYERCONTROLLER_TRANSFORM);
                    espView.localPos = GetGlobalPosition(localTransform);
                    espView.localTeam = (int)ReadUInt8(local + OFFSET_PLAYERCONTROLLER_TEAM);
                    
                    NSMutableArray *playersArray = [NSMutableArray array];
                    uintptr_t playerList = GetPlayerList();
                    
                    if (playerList) {
                        int playerCount = GetPlayerCount();
                        for (int i = 0; i < playerCount; i++) {
                            uintptr_t photonPlayer = ReadPtr(playerList + i * sizeof(uintptr_t));
                            if (!photonPlayer) continue;
                            if (ReadUInt8(photonPlayer + OFFSET_PHOTONPLAYER_ISLOCAL)) continue;
                            
                            int actorId = (int)ReadUInt32(photonPlayer + OFFSET_PHOTONPLAYER_ACTORID);
                            if (actorId == 0) continue;
                            
                            uintptr_t controller = GetControllerFromPhotonPlayer(photonPlayer);
                            if (controller && controller != local) {
                                SkeletonBones bones = GetPlayerBones(controller);
                                int team = (int)ReadUInt8(controller + OFFSET_PLAYERCONTROLLER_TEAM);
                                int playerId = (int)ReadUInt32(controller + OFFSET_PLAYERCONTROLLER_PLAYERID);
                                uint8_t isAlive = ReadUInt8(controller + OFFSET_PLAYERCONTROLLER_ISPREINITIALIZED);
                                
                                if (!isAlive) continue;
                                if (team == localTeam) continue;
                                
                                NSMutableDictionary *playerData = [NSMutableDictionary dictionary];
                                [playerData setObject:[NSData dataWithBytes:&bones length:sizeof(SkeletonBones)] forKey:@"bones"];
                                [playerData setObject:[NSNumber numberWithInt:team] forKey:@"team"];
                                [playerData setObject:[NSNumber numberWithBool:NO] forKey:@"isMine"];
                                [playerData setObject:[NSNumber numberWithBool:isAlive] forKey:@"isAlive"];
                                [playerData setObject:[NSNumber numberWithInt:playerId] forKey:@"playerId"];
                                [playersArray addObject:playerData];
                            }
                        }
                    }
                    
                    espView.players = playersArray;
                    [espView setNeedsDisplay];
                }
            }];
        });
        
        WriteLog(@"=== CHEAT INIT COMPLETED ===");
    }
}
