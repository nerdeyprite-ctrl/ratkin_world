// 랫킨 생성기 메인 로직

// 설정 값
const WALK_PROBABILITY = 0.7; // 걷기 확률 70%
const RUN_PROBABILITY = 0.3;  // 뛰기 확률 30%
const DECISION_INTERVAL = 3000; // 행동 변경 간격 (3초)
const WALK_SPEED = 1; // 걷기 속도
const RUN_SPEED = 3;  // 뛰기 속도
const AUTO_SPEECH_CHANCE = 0.005; // 프레임당 자동 대사 확률 (약 0.5%)
const COLLISION_DISTANCE = 40; // 충돌 감지 거리 (픽셀)

// DOM 요소 가져오기
const world = document.getElementById('world');
const generateBtn = document.getElementById('generate-btn');
const resetBtn = document.getElementById('reset-btn');

// 랫킨들을 관리할 배열
let ratkins = [];

// 랫킨이 할 수 있는 말들
const MESSAGES = [
    "안녕! 👋",
    "치즈 있어? 🧀",
    "오늘 날씨 좋다! ☀️",
    "킁킁... 👃",
    "나 잡아봐라! 💨",
    "졸려... 💤",
    "배고파요 🍙",
    "찍찍! 🐭",
    "사랑해! ❤️",
    "행복해! ✨"
];

/**
 * 랫킨 클래스
 * 각 랫킨의 상태, 위치, 움직임을 관리합니다.
 */
class Ratkin {
    constructor(id) {
        this.id = id;
        this.x = Math.random() * (world.clientWidth - 48); // 초기 X 위치 (랜덤)
        this.y = Math.random() * (world.clientHeight - 48); // 초기 Y 위치 (랜덤)
        this.vx = 0; // X 속도
        this.vy = 0; // Y 속도
        this.state = 'walk'; // 초기 상태
        this.direction = 1; // 1: 오른쪽, -1: 왼쪽 (스프라이트 방향용)
        this.speed = WALK_SPEED;
        this.lastDecisionTime = Date.now(); // 마지막으로 행동을 결정한 시간
        this.frame = 0; // 애니메이션 프레임 (0 또는 1)
        this.frameTimer = 0; // 프레임 변경 타이머

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
     * 행동 결정 (3초마다 호출됨)
     * 걷기(70%) 또는 뛰기(30%)를 결정하고 이동 벡터를 랜덤으로 설정합니다.
     */
    makeDecision() {
        const rand = Math.random();
        if (rand < WALK_PROBABILITY) {
            this.state = 'walk';
            this.speed = WALK_SPEED;
            this.spriteElement.style.backgroundImage = "url('assets/ratkin_walk_sheet.png')";
        } else {
            this.state = 'run';
            this.speed = RUN_SPEED;
            this.spriteElement.style.backgroundImage = "url('assets/ratkin_run_sheet.png')";
        }

        // 랜덤 각도 생성 (0 ~ 2PI)
        const angle = Math.random() * Math.PI * 2;

        // 속도 벡터 계산
        this.vx = Math.cos(angle) * this.speed;
        this.vy = Math.sin(angle) * this.speed;

        // X축 이동 방향에 따라 스프라이트 방향 결정
        if (this.vx > 0) this.direction = 1;
        if (this.vx < 0) this.direction = -1;

        // 이미지 좌우 반전 처리
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

        // 3초마다 행동 결정
        if (now - this.lastDecisionTime > DECISION_INTERVAL) {
            this.makeDecision();
            this.lastDecisionTime = now;
        }

        // 위치 이동
        this.x += this.vx;
        this.y += this.vy;

        // 화면 밖으로 나가지 않게 처리 (벽에 부딪히면 튕김)
        if (this.x < 0) {
            this.x = 0;
            this.vx *= -1; // X축 반전
            this.direction = 1;
            this.updateDirectionStyle();
        } else if (this.x > world.clientWidth - 48) {
            this.x = world.clientWidth - 48;
            this.vx *= -1; // X축 반전
            this.direction = -1;
            this.updateDirectionStyle();
        }

        if (this.y < 0) {
            this.y = 0;
            this.vy *= -1; // Y축 반전
        } else if (this.y > world.clientHeight - 48) {
            this.y = world.clientHeight - 48;
            this.vy *= -1; // Y축 반전
        }

        // 다른 랫킨과의 충돌 처리
        this.checkCollisions();

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

                // 간단한 물리: 속도 교환 (비슷한 질량이라고 가정)
                // 또는 단순히 방향 반전

                // 겹침 방지를 위해 살짝 밀어냄
                const angle = Math.atan2(dy, dx);
                const overlap = COLLISION_DISTANCE - distance;

                this.x -= Math.cos(angle) * overlap / 2;
                this.y -= Math.sin(angle) * overlap / 2;
                other.x += Math.cos(angle) * overlap / 2;
                other.y += Math.sin(angle) * overlap / 2;

                // 속도 반전 (튕기기)
                // 더 자연스러운 튕김을 위해 서로의 속도를 약간 섞거나 반전
                // 여기서는 단순하게 각자의 속도를 반전시킴 (벽에 부딪힌 것처럼)
                this.vx *= -1;
                this.vy *= -1;
                other.vx *= -1;
                other.vy *= -1;

                // 방향 업데이트
                if (this.vx > 0) this.direction = 1; else this.direction = -1;
                if (other.vx > 0) other.direction = 1; else other.direction = -1;

                this.updateDirectionStyle();
                other.updateDirectionStyle();
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
        const interval = this.state === 'run' ? 10 : 20;

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

        const message = MESSAGES[Math.floor(Math.random() * MESSAGES.length)];

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

// 게임 루프 시작
gameLoop();
