// 랫킨 생성기 메인 로직

// 설정 값
const WALK_PROBABILITY = 0.7; // 걷기 확률 70%
const RUN_PROBABILITY = 0.3;  // 뛰기 확률 30%
const IDLE_PROBABILITY = 0.1; // 대기 확률 10%

const DECISION_INTERVAL = 3000; // 기본 행동 변경 간격 (3초)
const IDLE_DURATION = 5000;    // 대기 상태 지속 시간 (5초)
const IDLE_FLIP_INTERVAL = 1000; // 대기 중 방향 전환 간격 (1초)

const WALK_SPEED = 1; // 걷기 속도
const RUN_SPEED = 3;  // 뛰기 속도
const AUTO_SPEECH_CHANCE = 0.005; // 프레임당 자동 대사 확률 (약 0.5%)
const COLLISION_DISTANCE = 40; // 기본 충돌 감지 거리 (픽셀) - 스케일에 따라 변함

// DOM 요소 가져오기
const world = document.getElementById('world');
const generateBtn = document.getElementById('generate-btn');
const resetBtn = document.getElementById('reset-btn');
const bgOuterPicker = document.getElementById('bg-outer-picker');
const bgInnerPicker = document.getElementById('bg-inner-picker');
const sizeSlider = document.getElementById('size-slider');
const sizeValue = document.getElementById('size-value');

// 랫킨들을 관리할 배열
let ratkins = [];
let ratkinScale = 2.0; // 기본 크기 배율

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
        "심심해... 💭",
        "뭐 재미있는 거 없나? 👀",
        "휴식 중... ☕️",
        "두리번 두리번"
    ],
    // 걷기 상태 전용
    walk: [
        "산책 중~ 🚶",
        "룰루랄라 🎵",
        "어디로 갈까?",
        "총총총..."
    ],
    // 뛰기 상태 전용
    run: [
        "나 잡아봐라! 💨",
        "바쁘다 바빠! 💦",
        "호다닥! 🏃",
        "배고파요 🍙", // 배고파서 뛰는 느낌
        "늦었다 늦었어! ⏰"
    ],
    // 매달리기 상태 전용 (드래그 중)
    drag: [
        "무서워! 😱",
        "신기해! ✨",
        "높아! ☁️",
        "살려줘! 🆘",
        "우와아! 🦅"
    ],
    // 놓아주기 상태 전용 (드롭 후)
    drop: [
        "아이코! 💫",
        "고마워! 💕",
        "휴... 💨",
        "땅이다! 🌱",
        "어질어질... 😵‍💫"
    ]
};

// 현재 드래그 중인 랫킨을 저장하는 변수
let draggedRatkin = null;

/**
 * 랫킨 클래스
 * 각 랫킨의 상태, 위치, 움직임을 관리합니다.
 */
class Ratkin {
    constructor(id) {
        this.id = id;

        // 초기 위치 설정 (화면 크기가 48보다 작을 경우 0으로 설정하여 오류 방지)
        const maxX = Math.max(0, world.clientWidth - (48 * ratkinScale));
        const maxY = Math.max(0, world.clientHeight - (48 * ratkinScale));

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
        this.isDragging = false; // 드래그 상태 여부
        this.dragTimer = null; // 꾹 누르기 타이머
        this.dragOffsetX = 0; // 드래그 시 마우스와 객체 간 X 오차
        this.dragOffsetY = 0; // 드래그 시 마우스와 객체 간 Y 오차

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

        // 마우스 다운 (타이머 시작)
        this.element.addEventListener('mousedown', (e) => {
            if (e.button !== 0) return; // 왼쪽 버튼만
            e.preventDefault();

            // 0.1초 후 드래그 시작
            this.dragTimer = setTimeout(() => {
                this.handleDragStart(e);
            }, 100);
        });

        // 마우스 업 (타이머 취소 및 클릭 처리)
        this.element.addEventListener('mouseup', (e) => {
            if (this.dragTimer) {
                clearTimeout(this.dragTimer);
                this.dragTimer = null;
            }

            // 드래그 중이 아니었다면 클릭으로 간주 (말풍선)
            if (!this.isDragging) {
                e.stopPropagation();
                this.sayHello();
            }
        });

        // 마우스 이탈 (타이머 취소)
        this.element.addEventListener('mouseleave', () => {
            if (this.dragTimer) {
                clearTimeout(this.dragTimer);
                this.dragTimer = null;
            }
        });

        world.appendChild(this.element);

        // 초기 행동 설정
        this.makeDecision();

        // 초기 크기 및 방향 적용
        this.updateTransform();
        this.updateDirectionStyle();
    }

    /**
     * 드래그 시작 (매달리기)
     */
    handleDragStart(e) {
        this.isDragging = true;
        draggedRatkin = this;

        // 드래그 오프셋 계산 (클릭한 위치와 객체 위치의 차이)
        const worldRect = world.getBoundingClientRect();
        const clientX = e.clientX;
        const clientY = e.clientY;

        this.dragOffsetX = clientX - worldRect.left - this.x;
        this.dragOffsetY = clientY - worldRect.top - this.y;

        // 상태 변경: 드래그
        this.state = 'drag';
        this.vx = 0;
        this.vy = 0;

        this.element.classList.add('dragging');

        // [확장 포인트] 매달리기 이미지
        this.spriteElement.style.backgroundImage = "url('assets/ratkin_run_sheet.png')";

        if (Math.random() < 0.5) {
            this.sayHello('drag');
        }
    }

    /**
     * 드롭 (놓아주기)
     */
    handleDrop() {
        this.isDragging = false;
        this.element.classList.remove('dragging');

        // 상태 변경: 대기
        this.state = 'idle';

        // [확장 포인트] 착지 이미지
        this.spriteElement.style.backgroundImage = "url('assets/ratkin_idle_sheet.png')";

        this.lastDecisionTime = Date.now();
        this.decisionDuration = 2000; // 2초간 대기

        this.sayHello('drop');
    }

    /**
     * 행동 결정
     */
    makeDecision() {
        if (this.isDragging) return;

        const rand = Math.random();

        // 10% 확률로 Idle
        if (rand < IDLE_PROBABILITY) {
            this.state = 'idle';
            this.speed = 0;
            this.vx = 0;
            this.vy = 0;
            this.decisionDuration = IDLE_DURATION; // 10초
            this.spriteElement.style.backgroundImage = "url('assets/ratkin_idle_sheet.png')";
            this.idleFlipTimer = 0;
        }
        // 63% 확률로 Walk
        else if (rand < 0.73) {
            this.state = 'walk';
            this.speed = WALK_SPEED;
            this.decisionDuration = DECISION_INTERVAL; // 3초
            this.spriteElement.style.backgroundImage = "url('assets/ratkin_walk_sheet.png')";
            this.setRandomVelocity();
        }
        // 27% 확률로 Run
        else {
            this.state = 'run';
            this.speed = RUN_SPEED;
            this.decisionDuration = DECISION_INTERVAL; // 3초
            this.spriteElement.style.backgroundImage = "url('assets/ratkin_run_sheet.png')";
            this.setRandomVelocity();
        }
    }

    /**
     * 랜덤 이동 벡터 설정
     */
    setRandomVelocity() {
        const angle = Math.random() * Math.PI * 2;
        this.vx = Math.cos(angle) * this.speed;
        this.vy = Math.sin(angle) * this.speed;

        if (this.vx > 0) this.direction = 1;
        if (this.vx < 0) this.direction = -1;

        this.updateDirectionStyle();
    }

    /**
     * 전체 크기 업데이트 (컨테이너 스케일)
     */
    updateTransform() {
        this.element.style.transform = `scale(${ratkinScale})`;
    }

    /**
     * 방향 스타일 업데이트 (스프라이트 반전만 담당)
     */
    updateDirectionStyle() {
        if (this.direction === 1) {
            this.spriteElement.style.transform = 'scaleX(1)';
        } else {
            this.spriteElement.style.transform = 'scaleX(-1)';
        }
    }

    /**
     * 매 프레임 업데이트
     */
    update() {
        if (this.isDragging) {
            this.animate();
            return;
        }

        const now = Date.now();

        if (now - this.lastDecisionTime > this.decisionDuration) {
            this.makeDecision();
            this.lastDecisionTime = now;
        }

        if (this.state === 'idle') {
            const elapsed = now - this.lastDecisionTime;
            const flipStep = Math.floor(elapsed / IDLE_FLIP_INTERVAL);

            if (flipStep !== this.idleFlipTimer) {
                this.direction *= -1;
                this.updateDirectionStyle();
                this.idleFlipTimer = flipStep;
            }
        } else {
            this.move();
        }

        this.element.style.left = `${this.x}px`;
        this.element.style.top = `${this.y}px`;

        this.animate();

        if (Math.random() < AUTO_SPEECH_CHANCE) {
            this.sayHello();
        }
    }

    /**
     * 이동 로직
     */
    move() {
        this.x += this.vx;
        this.y += this.vy;

        // 스케일이 적용된 크기만큼 경계 조정
        const scaledSize = 48 * ratkinScale;
        const maxX = Math.max(0, world.clientWidth - scaledSize);
        const maxY = Math.max(0, world.clientHeight - scaledSize);

        if (this.x < 0) {
            this.x = 0;
            this.vx *= -1;
            this.direction = 1;
            this.updateDirectionStyle();
        } else if (this.x > maxX) {
            this.x = maxX;
            this.vx *= -1;
            this.direction = -1;
            this.updateDirectionStyle();
        }

        if (this.y < 0) {
            this.y = 0;
            this.vy *= -1;
        } else if (this.y > maxY) {
            this.y = maxY;
            this.vy *= -1;
        }

        this.checkCollisions();
    }

    /**
     * 충돌 처리
     */
    checkCollisions() {
        // 스케일에 따른 충돌 거리 조정
        const currentCollisionDist = COLLISION_DISTANCE * (ratkinScale / 2);

        for (let other of ratkins) {
            if (other === this) continue;

            const dx = other.x - this.x;
            const dy = other.y - this.y;
            const distance = Math.sqrt(dx * dx + dy * dy);

            if (distance < currentCollisionDist) {
                const angle = Math.atan2(dy, dx);
                const overlap = currentCollisionDist - distance;

                this.x -= Math.cos(angle) * overlap / 2;
                this.y -= Math.sin(angle) * overlap / 2;
                other.x += Math.cos(angle) * overlap / 2;
                other.y += Math.sin(angle) * overlap / 2;

                if (this.state !== 'idle') {
                    this.vx *= -1;
                    this.vy *= -1;
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
     * 애니메이션
     */
    animate() {
        this.frameTimer++;
        let interval = 20;
        if (this.state === 'run' || this.state === 'drag') interval = 10;

        if (this.frameTimer > interval) {
            this.frame = 1 - this.frame;
            const positionX = this.frame === 0 ? '0px' : '-48px';
            this.spriteElement.style.backgroundPosition = `${positionX} 0px`;
            this.frameTimer = 0;
        }
    }

    /**
     * 말풍선 띄우기
     */
    sayHello(forcedState = null) {
        if (this.element.querySelector('.bubble')) {
            if (forcedState) {
                this.element.querySelector('.bubble').remove();
            } else {
                return;
            }
        }

        let targetState = forcedState || this.state;
        let availableMessages = [...MESSAGES.common];

        if (MESSAGES[targetState]) {
            if (targetState === 'drag' || targetState === 'drop') {
                availableMessages = MESSAGES[targetState];
            } else {
                availableMessages = availableMessages.concat(MESSAGES[targetState]);
            }
        }

        const message = availableMessages[Math.floor(Math.random() * availableMessages.length)];

        const bubble = document.createElement('div');
        bubble.classList.add('bubble');
        bubble.innerText = message;

        // 말풍선 위치 조정 (스케일 고려 안함 - 컨테이너가 스케일되므로)
        const ratioX = this.x / world.clientWidth;

        if (ratioX < 0.1) {
            bubble.style.left = '0';
            bubble.style.transform = 'translateX(0)';
        } else if (ratioX > 0.9) {
            bubble.style.left = 'auto';
            bubble.style.right = '0';
            bubble.style.transform = 'translateX(0)';
        } else {
            bubble.style.left = '50%';
            bubble.style.transform = 'translateX(-50%)';
        }

        this.element.appendChild(bubble);

        setTimeout(() => {
            if (bubble && bubble.parentNode) {
                bubble.remove();
            }
        }, 2000);
    }

    remove() {
        this.element.remove();
    }
}

/**
 * 성자 랫킨 클래스 (Ratkin 상속)
 * 10% 확률로 등장하며 기도하는 행동을 함
 */
class SaintRatkin extends Ratkin {
    constructor(id) {
        super(id);
        // 초기 이미지 설정 (성자 걷기)
        this.spriteElement.style.backgroundImage = "url('assets/saint_ratkin_walk_sheet.png')";
        this.spriteElement.style.backgroundSize = ''; // 기본값 사용 (96px 48px)
    }

    /**
     * 행동 결정 (오버라이드)
     */
    makeDecision() {
        if (this.isDragging) return;

        const rand = Math.random();

        // 10% 확률로 Pray (기도)
        if (rand < 0.1) {
            this.state = 'pray';
            this.speed = 0;
            this.vx = 0;
            this.vy = 0;
            this.decisionDuration = 10000; // 10초
            this.spriteElement.style.backgroundImage = "url('assets/saint_ratkin_pray_sheet.png')";
            this.spriteElement.style.backgroundSize = '48px 48px'; // 단일 프레임 크기 고정
            this.idleFlipTimer = 0;

            // 기도 시작 시 대사 (100% 확률)
            this.sayHello('pray');
        }
        // 90% 확률로 Walk (걷기)
        else {
            this.state = 'walk';
            this.speed = WALK_SPEED;
            this.decisionDuration = DECISION_INTERVAL; // 3초
            this.spriteElement.style.backgroundImage = "url('assets/saint_ratkin_walk_sheet.png')";
            this.spriteElement.style.backgroundSize = ''; // 기본값 복구
            this.setRandomVelocity();
        }
    }

    /**
     * 드래그 시작 (오버라이드)
     */
    handleDragStart(e) {
        super.handleDragStart(e); // 기본 로직 실행 (상태 변경, 오프셋 계산 등)

        // 이미지 변경 (기도하는 모습으로 매달림)
        this.spriteElement.style.backgroundImage = "url('assets/saint_ratkin_pray_sheet.png')";
        this.spriteElement.style.backgroundSize = '48px 48px'; // 단일 프레임 크기 고정

        // 대사 처리 (50% 확률)
        if (Math.random() < 0.5) {
            this.sayHello('drag');
        }
    }

    /**
     * 드롭 (오버라이드)
     */
    handleDrop() {
        this.isDragging = false;
        this.element.classList.remove('dragging');

        // 상태 변경: 기도 (착지 후 감사 기도)
        this.state = 'pray';

        // 이미지 변경
        this.spriteElement.style.backgroundImage = "url('assets/saint_ratkin_pray_sheet.png')";
        this.spriteElement.style.backgroundSize = '48px 48px'; // 단일 프레임 크기 고정

        this.lastDecisionTime = Date.now();
        this.decisionDuration = 3000; // 3초간 유지

        // 대사 처리 (100% 확률)
        this.sayHello('drop');
    }

    /**
     * 말풍선 띄우기 (오버라이드)
     */
    sayHello(forcedState = null) {
        // 기존 말풍선 제거
        if (this.element.querySelector('.bubble')) {
            this.element.querySelector('.bubble').remove();
        }

        let message = "";
        let duration = 2000; // 기본 지속 시간

        const targetState = forcedState || this.state;

        if (targetState === 'pray') {
            message = "쥐의 신, 설치류의 군주, 햄스터 바퀴를 돌리는 군주, \n 내 마음속 가려움을 긁어 주는 군주께 기도합니다..";
            duration = 10000; // 기도 시간만큼 유지
        } else if (targetState === 'drag') {
            message = "찍찍이 군주님 살려주세요...";
        } else if (targetState === 'drop') {
            message = "군주께 감사드립니다...";
            duration = 3000; // 3초 유지
        } else {
            // 그 외 상태는 일반 랫킨과 동일하거나 침묵
            if (Math.random() < 0.1) {
                message = "총총총...";
            } else {
                return; // 말 안함
            }
        }

        if (!message) return;

        const bubble = document.createElement('div');
        bubble.classList.add('bubble');
        bubble.innerText = message;

        // 말풍선 위치 조정
        const ratioX = this.x / world.clientWidth;
        if (ratioX < 0.1) {
            bubble.style.left = '0';
            bubble.style.transform = 'translateX(0)';
        } else if (ratioX > 0.9) {
            bubble.style.left = 'auto';
            bubble.style.right = '0';
            bubble.style.transform = 'translateX(0)';
        } else {
            bubble.style.left = '50%';
            bubble.style.transform = 'translateX(-50%)';
        }

        this.element.appendChild(bubble);

        setTimeout(() => {
            if (bubble && bubble.parentNode) {
                bubble.remove();
            }
        }, duration);
    }

    /**
     * 애니메이션 (오버라이드)
     */
    animate() {
        // 기도 상태와 드래그 상태(매달림)는 단일 프레임 (48x48)이므로 애니메이션 하지 않음
        if (this.state === 'pray' || this.state === 'drag') {
            this.spriteElement.style.backgroundPosition = '0px 0px';
            return;
        }

        // 그 외 상태는 부모의 애니메이션 로직 따름
        super.animate();
    }

    /**
     * 업데이트 (오버라이드)
     */
    update() {
        // 드래그 중일 때는 애니메이션만 처리
        if (this.isDragging) {
            this.animate();
            return;
        }

        const now = Date.now();

        // 행동 결정 시간 체크
        if (now - this.lastDecisionTime > this.decisionDuration) {
            this.makeDecision();
            this.lastDecisionTime = now;
        }

        // 기도 상태일 때는 움직이지 않고 방향도 바꾸지 않음
        if (this.state === 'pray') {
            // 위치 고정 (혹시 모를 미세 이동 방지)
            this.element.style.left = `${this.x}px`;
            this.element.style.top = `${this.y}px`;

            this.animate(); // 애니메이션 (기도는 정지 이미지)

            // 기도 중에는 자동 대사 금지 (엄숙하게)
        } else {
            // 그 외 상태(걷기 등)는 부모 로직 따름
            super.update();
        }
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

    document.documentElement.style.setProperty('--bg-outer', outerColor);
    document.documentElement.style.setProperty('--bg-inner', innerColor);

    const r = parseInt(innerColor.substr(1, 2), 16);
    const g = parseInt(innerColor.substr(3, 2), 16);
    const b = parseInt(innerColor.substr(5, 2), 16);

    const patternR = Math.floor(r * 0.85);
    const patternG = Math.floor(g * 0.85);
    const patternB = Math.floor(b * 0.85);

    const patternColor = `rgb(${patternR}, ${patternG}, ${patternB})`;
    document.documentElement.style.setProperty('--bg-pattern', patternColor);

    const borderR = Math.floor(r * 0.7);
    const borderG = Math.floor(g * 0.7);
    const borderB = Math.floor(b * 0.7);
    const borderColor = `rgb(${borderR}, ${borderG}, ${borderB})`;
    document.documentElement.style.setProperty('--bg-border', borderColor);
}

// 크기 변경 함수
function updateSize() {
    ratkinScale = parseFloat(sizeSlider.value);
    sizeValue.innerText = `${ratkinScale.toFixed(1)}x`; // 배율 텍스트 업데이트

    // 모든 랫킨에게 즉시 적용
    ratkins.forEach(ratkin => {
        ratkin.updateTransform();
        ratkin.updateDirectionStyle(); // 방향도 다시 업데이트 (혹시 모를 싱크 맞춤)
    });
}

// 이벤트 리스너 등록
generateBtn.addEventListener('click', () => {
    const id = Date.now();
    let newRatkin;

    // 10% 확률로 성자 랫킨 생성
    if (Math.random() < 0.1) {
        newRatkin = new SaintRatkin(id);
    } else {
        newRatkin = new Ratkin(id);
    }

    ratkins.push(newRatkin);
});

resetBtn.addEventListener('click', () => {
    ratkins.forEach(ratkin => ratkin.remove());
    ratkins = [];
});

bgOuterPicker.addEventListener('input', updateColors);
bgInnerPicker.addEventListener('input', updateColors);
sizeSlider.addEventListener('input', updateSize);

// 전역 드래그 이벤트 리스너
document.addEventListener('mousemove', (e) => {
    if (draggedRatkin) {
        e.preventDefault();

        const worldRect = world.getBoundingClientRect();

        // 스케일 고려하여 중심점 잡기 (대략적으로)
        const scaledSize = 48 * ratkinScale;

        // 오프셋을 적용하여 위치 계산
        let newX = e.clientX - worldRect.left - draggedRatkin.dragOffsetX;
        let newY = e.clientY - worldRect.top - draggedRatkin.dragOffsetY;

        newX = Math.max(0, Math.min(newX, world.clientWidth - scaledSize));
        newY = Math.max(0, Math.min(newY, world.clientHeight - scaledSize));

        draggedRatkin.x = newX;
        draggedRatkin.y = newY;

        draggedRatkin.element.style.left = `${newX}px`;
        draggedRatkin.element.style.top = `${newY}px`;
    }
});

document.addEventListener('mouseup', () => {
    if (draggedRatkin) {
        draggedRatkin.handleDrop();
        draggedRatkin = null;
    }
});

// 게임 루프 시작
gameLoop();
