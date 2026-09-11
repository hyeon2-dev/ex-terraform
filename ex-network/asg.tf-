# aws_launch_template.std19_ex_lt
# asg.tf
# ==========================================================================
# 대상 그룹 생성: aws_lb_target_group
# ==========================================================================
resource "aws_lb_target_group" "std19_ex_nginx_tg" {
    name            = "std19-ex-nginx-tg"
    vpc_id          = aws_vpc.std19_lab_vpc.id

    protocol        = "HTTP"
    port            = 80    # 내부 웹서버의 실행 포트번호

    # 인스턴스 연결 대기 시간 정의
    slow_start              = 30 # 초
    # 인스턴스 종료(삭제)시 연결 유지 시간
    deregistration_delay    = 60 

    # 헬스 체크
    health_check {
        protocol    = "HTTP"
        path        = "/"
        port        = "traffic-port"    # 기본값으로 위 서비스의 포트번호를 따라감

        interval    = 15    # 15초마다 한번씩 검사
        timeout     = 5     # 응답을 기다리는 시간 (5초안에 응답이 없으면 실패)

        # 최종 성공/실패의 인정기준(횟수)
        healthy_threshold   = 3 # 3번 연속 성공하면 '정상'
        unhealthy_threshold = 3 # 3번 연속 실패하면 '실패'
    }


    tags            = { Name = "std19-ex-nginx-tg"}
    
}


# ==========================================================================
# ASG 생성: aws_autoscaling_group
# ==========================================================================
resource "aws_autoscaling_group" "std19_ex_nginx_asg" {
    name                = "std19-ex-nginx-asg"
    min_size            = 1
    max_size            = 3
    desired_capacity    = 2

    # 네트워크(subnet.id)
    vpc_zone_identifier = [
        aws_subnet.std19_public_subnet[local.azs[0]].id,
        aws_subnet.std19_public_subnet[local.azs[1]].id,
        aws_subnet.std19_public_subnet[local.azs[2]].id,
        aws_subnet.std19_public_subnet[local.azs[3]].id
    ]

    # 대상 그룹(ARN)
    target_group_arns = [
        aws_lb_target_group.std19_ex_nginx_tg.arn
    ]

    # 시작 템플릿 구성
    launch_template {
        id          = aws_launch_template.std19_ex_lt.id
        version     = "$Latest"
    }

    # 헬스 체크
    health_check_type           = "EC2" # ELB
    health_check_grace_period   = 300

    tag { 
        key                 = "Name"
        value               = "std19-ex-nginx-asg"
        propagate_at_launch = false  # EC2 인스턴스에도 동일한 태그를 적용할지? (ture/false)
    }
}

# =======================================================================================
# ASG Policy 생성: aws_autoscaling_policy
# 인스턴스 수량 조정의 기준
# =======================================================================================
resource "aws_autoscaling_policy" "std19_asg_policy" {
    name                    = "std19-asg-policy"
    autoscaling_group_name  = aws_autoscaling_group.std19_ex_nginx_asg.name

    # 조정 정책
    policy_type             = "TargetTrackingScaling"   # 대상 추적 방식

    target_tracking_configuration {
        predefined_metric_specification{
            predefined_metric_type  = "ASGAverageCPUUtilization"    # CPU 사용율 기준
        }

        target_value    = 50.0  # 목표 CPU 사용률 (50% ~ 70%권장)
    }
}

# =======================================================================================
# ASG 예약 정책: aws_autoscaling_schedule
# =======================================================================================
# 1. 평일 아침 8시 30분: 인스턴스 확장 (Scale-out)
# resource "aws_autoscaling_schedule" "scale_out" {
#     scheduled_action_name   = "std19-scale-out"
#     autoscaling_group_name  = aws_autoscaling_group.std19_ex_nginx_asg.name

#     # 인스턴스 수량 설정
#     min_size            = 2
#     max_size            = 5
#     desired_capacity    = 4

#     # 실행 주기 (Cron 표현식: 분 시 일 월 요일)
#     # KST(UTC+9) 12:35(UTC시간은 한국시간 - 9)
#     recurrence  = "10 13 * * 1-5"   # 월금 KST 13:06 실행
#     time_zone   = "Asia/Seoul"      # 최신 AWS 프로바이더에서는 time_zone 지정 가능
# }

# resource "aws_autoscaling_schedule" "scale_in" {
#     scheduled_action_name   = "std19-scale-in"
#     autoscaling_group_name  = aws_autoscaling_group.std19_ex_nginx_asg.name

#     # 인스턴스 수량 설정
#     min_size            = 1
#     max_size            = 2
#     desired_capacity    = 1

#     # 실행 주기 (Cron 표현식: 분 시 일 월 요일)
#     # KST(UTC+9) 12:35(UTC시간은 한국시간 - 9)
#     recurrence  = "13 13 * * 1-5"   # 월금 KST 13:11 실행
#     time_zone   = "Asia/Seoul"      # 최신 AWS 프로바이더에서는 time_zone 지정 가능
# }

