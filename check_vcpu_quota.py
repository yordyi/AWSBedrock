#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import boto3
from botocore.exceptions import NoCredentialsError, PartialCredentialsError, ClientError

def get_vcpus_for_instance_type(instance_type, ec2_client):
    """
    调用 describe_instance_types 获取对应的 vCPU 数。
    """
    response = ec2_client.describe_instance_types(InstanceTypes=[instance_type])
    vcpus = response['InstanceTypes'][0]['VCpuInfo']['DefaultVCpus']
    return vcpus

def get_used_vcpus(ec2_client):
    """
    统计当前帐号下正在使用的 (running) On-Demand 实例所占用的 vCPU 数量。
    """
    used_vcpus = 0
    paginator = ec2_client.get_paginator('describe_instances')

    for page in paginator.paginate(Filters=[
        {'Name': 'instance-state-name', 'Values': ['running']}
    ]):
        for reservation in page['Reservations']:
            for instance in reservation['Instances']:
                instance_type = instance['InstanceType']
                used_vcpus += get_vcpus_for_instance_type(instance_type, ec2_client)

    return used_vcpus

def main():
    print("欢迎使用 EC2 vCPU 配额检查和自动申请工具\n")

    # ---------------------------
    # 1. 交互式输入 AWS 凭证
    # ---------------------------
    aws_access_key_id = input("请输入 AWS Access Key ID（若留空，则使用默认配置）: ").strip()
    aws_secret_access_key = input("请输入 AWS Secret Access Key（若留空，则使用默认配置）: ").strip()

    # 如果是临时凭证，需要同时输入 Session Token
    # 如果是长期凭证，可以直接回车跳过
    aws_session_token = input("如果使用临时凭证，请输入 Session Token (若留空，则视为长期凭证): ").strip()

    region = input("\n请输入要操作的 AWS 区域(默认 'us-east-1')，例如 'us-west-2': ").strip()
    if not region:
        region = "us-east-1"

    # ---------------------------
    # 2. 创建 Boto3 Client
    # ---------------------------
    try:
        ec2_client = boto3.client(
            'ec2',
            region_name=region,
            aws_access_key_id=aws_access_key_id if aws_access_key_id else None,
            aws_secret_access_key=aws_secret_access_key if aws_secret_access_key else None,
            aws_session_token=aws_session_token if aws_session_token else None
        )

        sq_client = boto3.client(
            'service-quotas',
            region_name=region,
            aws_access_key_id=aws_access_key_id if aws_access_key_id else None,
            aws_secret_access_key=aws_secret_access_key if aws_secret_access_key else None,
            aws_session_token=aws_session_token if aws_session_token else None
        )

    except (NoCredentialsError, PartialCredentialsError) as e:
        print("无法获取到有效的 AWS 凭证，请检查配置或手动输入。")
        print(f"错误详情: {e}")
        return

    # ---------------------------
    # 3. 获取当前 vCPU 配额
    # ---------------------------
    service_code = 'ec2'
    quota_code = 'L-1216C47A'  # On-Demand Standard (A, C, D, H, I, M, R, T, Z) Instances

    print("\n正在查询当前 EC2 vCPU 配额...")
    try:
        response = sq_client.get_service_quota(
            ServiceCode=service_code,
            QuotaCode=quota_code
        )
        current_quota = response['Quota']['Value']
        print(f"当前 vCPU 配额为：{current_quota}")
    except ClientError as e:
        print(f"查询配额失败，请检查权限或参数：{e}")
        return

    # ---------------------------
    # 4. (可选) 获取当前已使用的 vCPU 数量
    # ---------------------------
    check_usage = input("\n是否需要查看当前正在使用的 vCPU 数量？(y/n，默认 n): ").strip().lower()
    if check_usage == 'y':
        try:
            used_vcpus = get_used_vcpus(ec2_client)
            print(f"当前正在使用的 vCPU 数量为：{used_vcpus}")
        except ClientError as e:
            print(f"查询正在使用的 vCPU 数量失败：{e}")
            return

    # ---------------------------
    # 5. 让用户输入要申请的配额额度
    # ---------------------------
    print("\n如果你需要提高配额，请在此输入大于当前配额的数值；若不需提高，可输入小于或等于当前配额的值。")
    desired_str = input("请输入要申请的 vCPU 配额额度(仅数字)，或直接回车跳过: ").strip()
    if not desired_str:
        print("未输入任何值，程序退出。")
        return

    try:
        desired_quota = float(desired_str)
    except ValueError:
        print("输入无效，请输入数字类型。程序退出。")
        return

    if desired_quota <= current_quota:
        print(f"你输入的额度 {desired_quota} 小于或等于当前额度 {current_quota}，无需申请提升。程序退出。")
        return

    # ---------------------------
    # 6. 提交配额提升申请
    # ---------------------------
    print(f"\n即将为你申请将配额从 {current_quota} 提升到 {desired_quota}，请稍候...")
    try:
        increase_response = sq_client.request_service_quota_increase(
            ServiceCode=service_code,
            QuotaCode=quota_code,
            DesiredValue=desired_quota
        )
        request_id = increase_response['RequestedQuota']['Id']
        print(f"已提交配额提升申请，请等待 AWS 审批。\n申请ID: {request_id}")
    except ClientError as e:
        print(f"申请配额提升时出错：{e}")


if __name__ == '__main__':
    main()
