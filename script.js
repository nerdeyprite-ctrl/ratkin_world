// 랫킨 생성기 메인 로직

// 설정 값
const WALK_PROBABILITY = 0.7; // 걷기 확률 70%
const RUN_PROBABILITY = 0.3;  // 뛰기 확률 30%
const IDLE_PROBABILITY = 0.1; // 대기 확률 10% (걷기/뛰기 결정 전에 먼저 체크하거나 포함해서 계산)
// 확률 조정: 
// Idle: 10%
// 나머지 90% 중에서: Walk 70%, Run 30% (비율 유지) -> Walk: 63%, Run: 27%
// 편의상 단순하게: 0~0.1: Idle, 0.1~0.73: Walk, 0.73~1.0: Run

const DECISION_INTERVAL = 3000; // 기본 행동 변경 간격 (3초)
const IDLE_DURATION = 10000;    // 대기 상태 지속 시간 (10초)
const IDLE_FLIP_INTERVAL = 700; // 대기 중 방향 전환 간격 (0.7초)

const WALK_SPEED = 1; // 걷기 속도
const RUN_SPEED = 3;  // 뛰기 속도
const AUTO_SPEECH_CHANCE = 0.005; // 프레임당 자동 대사 확률 (약 0.5%)
const COLLISION_DISTANCE = 40; // 충돌 감지 거리 (픽셀)

// DOM 요소 가져오기
const world = document.getElementById('world');
const generateBtn = document.getElementById('generate-btn');
const resetBtn = document.getElementById('reset-btn');
const bgOuterPicker = document.getElementById('bg-outer-picker');
const bgInnerPicker = document.getElementById('bg-inner-picker');

// 랫킨들을 관리할 배열
let ratkins = [];

// 랫킨이 할 수 있는 말들 (상태별 분리)
const MESSAGES = {
    // 공통 메시지 (모든 상태에서 나올 수 있음)
    common: [
        "안녕! 👋",
        "치즈 있어? 🧀",
        "오늘 날씨 좋다! ☀️",
        "킁킁... 👃",
        "찍찍! 🐭",
        "사랑해! ❤️",
        "행복해! ✨"
    ],
    // 대기 상태 전용
    idle: [
        "둠칫둠칫 🎶",
        "심심해... 🤔",
        "뭐 재미있는 거 없나? 👀",
        "휴식 중... ☕️",
        "두리번 두리번"
    ],
    // 걷기 상태 전용
    walk: [
        "산책 중~ 🏃",
        "룰루랄라 🎶",
        "어디로 갈까?",
        "총총총..."
    ],
    // 뛰기 상태 전용
    run: [
        "나 잡아봐라! 🐭",
        "바쁘다 바빠! 💦",
        "호다닥! 🏃",
        "배고파요 🍙", // 배고파서 뛰는 느낌
        "늦었다 늦었어! ⏰"
    ]
};

/**
 * 랫킨 클래스
 * 각 랫킨의 상태, 위치, 움직임을 관리합니다.
 */
class Ratkin {
    // ... (constructor and other methods unchanged) ...

    // ... (makeDecision, setRandomVelocity, updateDirectionStyle, update, move, checkCollisions, animate methods unchanged) ...

    /**
     * 상호작용: 말풍선 띄우기
     */
    sayHello() {
        // 이미 말하고 있으면 무시 (너무 시끄럽지 않게)
        if (this.element.querySelector('.bubble')) return;

        // 현재 상태에 맞는 메시지 목록 가져오기
        let availableMessages = [...MESSAGES.common]; // 공통 메시지는 항상 포함

        if (MESSAGES[this.state]) {
            availableMessages = availableMessages.concat(MESSAGES[this.state]);
        }

        const message = availableMessages[Math.floor(Math.random() * availableMessages.length)];

        const bubble = document.createElement('div');
        bubble.classList.add('bubble');
        bubble.innerText = message;

        // 말풍선 위치 조정 로직 (화면 밖으로 나가지 않게)
        // 기본적으로 중앙 정렬이지만, 가장자리에 있으면 조정

        // 랫킨의 현재 화면상 위치 비율 (0 ~ 1)
        const ratioX = this.x / world.clientWidth;

        if (ratioX < 0.1) {
            // 왼쪽 가장자리: 말풍선 왼쪽 정렬
            bubble.style.left = '0';
            bubble.style.transform = 'translateX(0)';
        } else if (ratioX > 0.9) {
            // 오른쪽 가장자리: 말풍선 오른쪽 정렬
            bubble.style.left = 'auto';
            bubble.style.right = '0';
            bubble.style.transform = 'translateX(0)';
        } else {
            // 기본: 중앙 정렬
            bubble.style.left = '50%';
            bubble.style.transform = 'translateX(-50%)';
        }

        // 말풍선은 컨테이너(.ratkin)에 추가
        this.element.appendChild(bubble);

        // 2초 뒤에 사라짐
        setTimeout(() => {
            if (bubble && bubble.parentNode) {
                bubble.remove();
            }
        }, 2000);
    }
    constructor(id) {
        this.id = id;

        // 초기 위치 설정 (화면 크기가 48보다 작을 경우 0으로 설정하여 오류 방지)
        const maxX = Math.max(0, world.clientWidth - 48);
        const maxY = Math.max(0, world.clientHeight - 48);

        this.x = Math.random() * maxX;
        this.y = Math.random() * maxY;

        this.vx = 0; // X 속도
        this.vy = 0; // Y 속도
        this.state = 'walk'; // 초기 상태
        this.direction = 1; // 1: 오른쪽, -1: 왼쪽 (스프라이트 방향용)
        this.speed = WALK_SPEED;

        this.lastDecisionTime = Date.now(); // 마지막으로 행동을 결정한 시간
        this.decisionDuration = DECISION_INTERVAL; // 현재 행동의 지속 시간

        this.frame = 0; // 애니메이션 프레임 (0 또는 1)
        this.frameTimer = 0; // 프레임 변경 타이머

        this.idleFlipTimer = 0; // 대기 상태 플립 타이머

        // DOM 요소 생성 (컨테이너)
        this.element = document.createElement('div');
        this.element.classList.add('ratkin');
        this.element.style.left = `${this.x}px`;
        this.element.style.top = `${this.y}px`;

        // 스프라이트 요소 생성 (이미지 담당)
        this.spriteElement = document.createElement('div');
        this.spriteElement.classList.add('ratkin-sprite');
        this.spriteElement.style.backgroundImage = "url('assets/ratkin_walk_sheet.png')"; // 기본 걷기 이미지 (스프라이트 시트)
        this.element.appendChild(this.spriteElement);

        // 클릭 이벤트 (상호작용)
        this.element.addEventListener('click', (e) => {
            e.stopPropagation(); // 버블 클릭 시 이벤트 전파 방지
            this.sayHello();
        });

        world.appendChild(this.element);

        // 초기 행동 설정
        this.makeDecision();
    }

    /**
     * 행동 결정
     */
    makeDecision() {
        const rand = Math.random();

        // 10% 확률로 Idle
        if (rand < IDLE_PROBABILITY) {
            this.state = 'idle';
            this.speed = 0;
            this.vx = 0;
            this.vy = 0;
            this.decisionDuration = IDLE_DURATION; // 10초 동안 지속
            this.spriteElement.style.backgroundImage = "url('assets/ratkin_idle_sheet.png')";
            this.idleFlipTimer = 0; // 타이머 초기화
        }
        // 나머지 90% 중에서 70:30 비율로 Walk/Run
        // 0.1 ~ 0.73 (63%) -> Walk
        else if (rand < 0.73) {
            this.state = 'walk';
            this.speed = WALK_SPEED;
            this.decisionDuration = DECISION_INTERVAL; // 3초
            this.spriteElement.style.backgroundImage = "url('assets/ratkin_walk_sheet.png')";
            this.setRandomVelocity();
        }
        // 0.73 ~ 1.0 (27%) -> Run
        else {
            this.state = 'run';
            this.speed = RUN_SPEED;
            this.decisionDuration = DECISION_INTERVAL; // 3초
            this.spriteElement.style.backgroundImage = "url('assets/ratkin_run_sheet.png')";
            this.setRandomVelocity();
        }
    }

    /**
     * 랜덤 이동 벡터 설정 (Walk/Run 상태용)
     */
    setRandomVelocity() {
        // 랜덤 각도 생성 (0 ~ 2PI)
        const angle = Math.random() * Math.PI * 2;

        // 속도 벡터 계산
        this.vx = Math.cos(angle) * this.speed;
        this.vy = Math.sin(angle) * this.speed;

        // X축 이동 방향에 따라 스프라이트 방향 결정
        if (this.vx > 0) this.direction = 1;
        if (this.vx < 0) this.direction = -1;

        this.updateDirectionStyle();
    }

    /**
     * 방향에 따른 이미지 스타일 업데이트
     * 컨테이너가 아닌 스프라이트만 반전시킴 (말풍선 영향 X)
     */
    updateDirectionStyle() {
        // 원본 이미지가 오른쪽을 보고 있다고 가정
        if (this.direction === 1) {
            this.spriteElement.style.transform = 'scaleX(1)';
        } else {
            this.spriteElement.style.transform = 'scaleX(-1)';
        }
    }

    /**
     * 매 프레임마다 호출되는 업데이트 함수
     */
    update() {
        const now = Date.now();

        // 행동 지속 시간이 지나면 새로운 행동 결정
        if (now - this.lastDecisionTime > this.decisionDuration) {
            this.makeDecision();
            this.lastDecisionTime = now;
        }

        // 상태별 로직
        if (this.state === 'idle') {
            // Idle 상태: 1초마다 방향 전환 (플립 효과)
            // requestAnimationFrame 기준이므로 대략적인 시간 계산 필요
            // 여기서는 간단히 now 시간을 이용

            // 현재 경과 시간
            const elapsed = now - this.lastDecisionTime;

            // 1초(1000ms) 단위로 방향이 바뀜
            // Math.floor(elapsed / 1000) 가 짝수면 1, 홀수면 -1 (또는 반대)
            const flipStep = Math.floor(elapsed / IDLE_FLIP_INTERVAL);

            // 이전 단계와 다르면 방향 전환
            if (flipStep !== this.idleFlipTimer) {
                this.direction *= -1; // 방향 반전
                this.updateDirectionStyle();
                this.idleFlipTimer = flipStep;
            }

        } else {
            // Walk/Run 상태: 이동 처리
            this.move();
        }

        // DOM 위치 업데이트
        this.element.style.left = `${this.x}px`;
        this.element.style.top = `${this.y}px`;

        // 애니메이션 (스프라이트 교체)
        this.animate();

        // 랜덤 대사 (가끔씩 혼자 말함)
        if (Math.random() < AUTO_SPEECH_CHANCE) {
            this.sayHello();
        }
    }

    /**
     * 이동 로직 분리
     */
    move() {
        // 위치 이동
        this.x += this.vx;
        this.y += this.vy;

        // 이동 가능 범위 계산 (최소 0)
        const maxX = Math.max(0, world.clientWidth - 48);
        const maxY = Math.max(0, world.clientHeight - 48);

        // 화면 밖으로 나가지 않게 처리 (벽에 부딪히면 튕김)
        if (this.x < 0) {
            this.x = 0;
            this.vx *= -1; // X축 반전
            this.direction = 1;
            this.updateDirectionStyle();
        } else if (this.x > maxX) {
            this.x = maxX;
            this.vx *= -1; // X축 반전
            this.direction = -1;
            this.updateDirectionStyle();
        }

        if (this.y < 0) {
            this.y = 0;
            this.vy *= -1; // Y축 반전
        } else if (this.y > maxY) {
            this.y = maxY;
            this.vy *= -1; // Y축 반전
        }

        // 다른 랫킨과의 충돌 처리
        this.checkCollisions();
    }

    /**
     * 충돌 감지 및 처리
     */
    checkCollisions() {
        for (let other of ratkins) {
            if (other === this) continue; // 자기 자신은 제외

            const dx = other.x - this.x;
            const dy = other.y - this.y;
            const distance = Math.sqrt(dx * dx + dy * dy);

            if (distance < COLLISION_DISTANCE) {
                // 충돌 발생! 서로 반대 방향으로 튕겨나감

                // 겹침 방지를 위해 살짝 밀어냄
                const angle = Math.atan2(dy, dx);
                const overlap = COLLISION_DISTANCE - distance;

                this.x -= Math.cos(angle) * overlap / 2;
                this.y -= Math.sin(angle) * overlap / 2;
                other.x += Math.cos(angle) * overlap / 2;
                other.y += Math.sin(angle) * overlap / 2;

                // 속도 반전 (튕기기)
                // Idle 상태인 랫킨은 튕기지 않거나, 튕기면 움직이게 됨 (여기서는 단순 반전만 하므로 0이면 그대로 0)
                // Idle 상태인 랫킨을 밀면? -> 현재 로직상 vx, vy가 0이라 안 움직임.
                // 조금 더 자연스럽게 하려면 Idle 상태라도 밀려나게 해야 하지만, 
                // 일단은 움직이는 애들끼리만 튕기거나, 움직이는 애가 Idle 애를 밀고 나가는 식(여기선 그냥 겹침만 방지됨)

                if (this.state !== 'idle') {
                    this.vx *= -1;
                    this.vy *= -1;
                    // 방향 업데이트
                    if (this.vx > 0) this.direction = 1; else this.direction = -1;
                    this.updateDirectionStyle();
                }

                if (other.state !== 'idle') {
                    other.vx *= -1;
                    other.vy *= -1;
                    if (other.vx > 0) other.direction = 1; else other.direction = -1;
                    other.updateDirectionStyle();
                }
            }
        }
    }

    /**
     * 애니메이션 처리
     * 96x48 이미지에서 48x48 영역을 번갈아 보여줌
     */
    animate() {
        this.frameTimer++;
        // 뛰는 상태면 더 빨리 발을 구름
        // Idle 상태도 애니메이션(숨쉬기 등)이 있다면 여기서 처리
        // Idle 시트도 2프레임이라고 했으므로 똑같이 처리

        let interval = 20; // 기본 (Walk, Idle)
        if (this.state === 'run') interval = 10;

        if (this.frameTimer > interval) {
            this.frame = 1 - this.frame; // 0 -> 1, 1 -> 0 토글

            // 스프라이트 시트 위치 변경
            // 0번 프레임: 0px 0px
            // 1번 프레임: -48px 0px
            const positionX = this.frame === 0 ? '0px' : '-48px';
            this.spriteElement.style.backgroundPosition = `${positionX} 0px`;

            this.frameTimer = 0;
        }
    }

    /**
     * 상호작용: 말풍선 띄우기
     */
    sayHello() {
        // 이미 말하고 있으면 무시 (너무 시끄럽지 않게)
        if (this.element.querySelector('.bubble')) return;

        // 현재 상태에 맞는 메시지 목록 가져오기
        let availableMessages = [...MESSAGES.common]; // 공통 메시지는 항상 포함

        if (MESSAGES[this.state]) {
            availableMessages = availableMessages.concat(MESSAGES[this.state]);
        }

        const message = availableMessages[Math.floor(Math.random() * availableMessages.length)];

        const bubble = document.createElement('div');
        bubble.classList.add('bubble');
        bubble.innerText = message;

        // 말풍선 위치 조정 로직 (화면 밖으로 나가지 않게)
        // 기본적으로 중앙 정렬이지만, 가장자리에 있으면 조정

        // 랫킨의 현재 화면상 위치 비율 (0 ~ 1)
        const ratioX = this.x / world.clientWidth;

        if (ratioX < 0.1) {
            // 왼쪽 가장자리: 말풍선 왼쪽 정렬
            bubble.style.left = '0';
            bubble.style.transform = 'translateX(0)';
        } else if (ratioX > 0.9) {
            // 오른쪽 가장자리: 말풍선 오른쪽 정렬
            bubble.style.left = 'auto';
            bubble.style.right = '0';
            bubble.style.transform = 'translateX(0)';
        } else {
            // 기본: 중앙 정렬
            bubble.style.left = '50%';
            bubble.style.transform = 'translateX(-50%)';
        }

        // 말풍선은 컨테이너(.ratkin)에 추가
        this.element.appendChild(bubble);

        // 2초 뒤에 사라짐
        setTimeout(() => {
            if (bubble && bubble.parentNode) {
                bubble.remove();
            }
        }, 2000);
    }

    /**
     * 제거 (초기화 시 사용)
     */
    remove() {
        this.element.remove();
    }
}

// 게임 루프
function gameLoop() {
    ratkins.forEach(ratkin => ratkin.update());
    requestAnimationFrame(gameLoop);
}

// 색상 변경 함수
function updateColors() {
    const outerColor = bgOuterPicker.value;
    const innerColor = bgInnerPicker.value;

    // CSS 변수 업데이트
    document.documentElement.style.setProperty('--bg-outer', outerColor);
    document.documentElement.style.setProperty('--bg-inner', innerColor);

    // 패턴 색상은 innerColor보다 조금 더 어둡게 자동 계산 (간단히 필터 사용하거나 투명도 조절)
    // 여기서는 간단히 innerColor를 그대로 쓰되, CSS에서 투명도를 줬으므로 자연스럽게 섞임
    // 하지만 더 명확한 패턴을 위해 조금 다른 색을 쓰고 싶다면 계산 필요.
    // 일단은 innerColor와 동일하게 설정 (CSS radial-gradient에서 투명도 사용중이라 괜찮음)
    // 좀 더 눈에 띄게 하려면 보색이나 어두운 색을 써야 하는데, 
    // "색상 피커의 색감대로 땡땡이 배경 패턴 색도 같이 변해" -> innerColor 기반으로 변경

    // Hex -> RGB 변환 후 조금 어둡게 만들기
    const r = parseInt(innerColor.substr(1, 2), 16);
    const g = parseInt(innerColor.substr(3, 2), 16);
    const b = parseInt(innerColor.substr(5, 2), 16);

    // 20% 정도 어둡게 (0.8 곱하기)
    const patternR = Math.floor(r * 0.85);
    const patternG = Math.floor(g * 0.85);
    const patternB = Math.floor(b * 0.85);

    const patternColor = `rgb(${patternR}, ${patternG}, ${patternB})`;
    document.documentElement.style.setProperty('--bg-pattern', patternColor);

    // 테두리 색상도 비슷하게
    const borderR = Math.floor(r * 0.7);
    const borderG = Math.floor(g * 0.7);
    const borderB = Math.floor(b * 0.7);
    const borderColor = `rgb(${borderR}, ${borderG}, ${borderB})`;
    document.documentElement.style.setProperty('--bg-border', borderColor);
}

// 이벤트 리스너 등록
generateBtn.addEventListener('click', () => {
    const id = Date.now();
    const newRatkin = new Ratkin(id);
    ratkins.push(newRatkin);
});

resetBtn.addEventListener('click', () => {
    ratkins.forEach(ratkin => ratkin.remove());
    ratkins = [];
});

bgOuterPicker.addEventListener('input', updateColors);
bgInnerPicker.addEventListener('input', updateColors);

// 게임 루프 시작
gameLoop();
