resource "aws_lb_target_group" "std19_ex_nginx_tg2" {
    name            = "std19-ex-nginx-tg2"
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

    tags            = { Name = "std19-ex-nginx-tg2"}
}

# ==========================================================================
# 대상 그룹에 대상(인스턴스) 등록: aws_lb_target_group_attachment
# ==========================================================================
# resource "aws_lb_target_group_attachment" "std19_ex_tg_atta1" {
#     target_group_arn    = <타겟그룹의 arn>
#     target_id           = <인스턴스_id>
#     port                = <port_number>
# }

# ==========================================================================
# 로드 밸런서
# ==========================================================================
resource "aws_lb" "std19_ex_alb" {
    name        = "std19-ex-alb"
    internal    = false # 내부로드밸런서 생성(true/false-외부)
    load_balancer_type  = "application"
    subnets             = [  # subnet id
        aws_subnet.std19_public_subnet[local.azs[0]].id,
        aws_subnet.std19_public_subnet[local.azs[1]].id,
        aws_subnet.std19_public_subnet[local.azs[2]].id,
        aws_subnet.std19_public_subnet[local.azs[3]].id
    ]

    security_groups     = [
        aws_security_group.std19_external_alb_sg.id,
        aws_security_group.std19_ssh_sg.id
    ]

    tags = { Name = "std19-ex-alb" }
}

# ==========================================================================
# 로드밸런서에 리스너 추가
# ==========================================================================
resource "aws_lb_listener" "std19_ex_lb_http_listener" {
    load_balancer_arn       = aws_lb.std19_ex_alb.arn
    protocol                = "HTTP"
    port                    = 80    # 사용자(외부/브라우저) 포트번호

    default_action {
        type                = "forward" # 전달/승계(대상그룹), redirect, fixed-response(error 대응 페이지)
        target_group_arn    = aws_lb_target_group.std19_ex_nginx_tg2.arn
    }
}

resource "aws_lb_listener" "std19_ex_lb_https_listener" {
    load_balancer_arn       = aws_lb.std19_ex_alb.arn
    protocol                = "HTTPS"
    port                    = 443    # 사용자(외부/브라우저) 포트번호

    ssl_policy              = "ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09" # 권장 SSL 보안 정책
    certificate_arn         = "arn:aws:acm:us-west-2:925047940866:certificate/2c1052cf-c683-464d-a305-8098754408c8"

    default_action {
        type                = "forward" # 전달/승계(대상그룹), redirect, fixed-response(error 대응 페이지)
        target_group_arn    = aws_lb_target_group.std19_ex_nginx_tg2.arn
    }

    # 에러 유형에 대한 애응 페이지로 리다이렉트
    # default_action {
    #     type                = "fixed-response"
    #     fixed_response {
    #         content_type = "text/html"
    #         status_code  = "503"
    #         message_body = <<-EOF
    #             ~ HTML TAG ~
    #         EOF
    #     }
    # }
}

    


# ==========================================================================
# Listener에 경로 규칙 추가
# ==========================================================================
resource "aws_lb_listener_rule" "std19_ex_lb_http_listener_path_rule" {
    listener_arn             = aws_lb_listener.std19_ex_lb_http_listener.arn
    # 1~50,000 사이의 규칙 우선순위 지정, 낮을수록 우선수위가 높음
    priority                = 100
    action {
        type                = "forward"
        target_group_arn    = aws_lb_target_group.std19_ex_nginx_tg2.arn
    }

    # 경로 변환
    # transform {
    #     type = "url-rewrite"

    #     url_rewrite_config {
    #         rewrite {
    #             regex   = "^/api/?(.*)" # 정규식
    #             replace = "/$1"         # 교체값
    #         }
    #     }
    # }

    # [라우팅 조건] URL 경로 정의
    condition {
        path_pattern {
            values = ["/api", "api/*"]
        }
    }
}

output "alb_dns" {
    value = aws_lb.std19_ex_alb.dns_name
}


# ==========================================================================
# ASG 생성: aws_autoscaling_group
# ==========================================================================
resource "aws_autoscaling_group" "std19_ex_nginx_asg2" {
    name                = "std19-ex-nginx-asg2"
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
        aws_lb_target_group.std19_ex_nginx_tg2.arn
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
        value               = "std19-ex-nginx-asg2"
        propagate_at_launch = false  # EC2 인스턴스에도 동일한 태그를 적용할지? (ture/false)
    }
}
