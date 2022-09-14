resource "aws_efs_file_system" "efs_for_lambda" {
  tags = {
    Name = "efs.lambda-ocr-module"
  }
}

resource "aws_efs_mount_target" "alpha" {
  for_each        = var.public_subnet_numbers
  file_system_id  = aws_efs_file_system.efs_for_lambda.id
  subnet_id       = aws_subnet.subnet_for_lambda[each.key].id
  security_groups = [aws_security_group.sg_for_lambda.id]
}

resource "aws_efs_access_point" "access_point_for_lambda" {
  file_system_id = aws_efs_file_system.efs_for_lambda.id

  root_directory {
    path = "/lambda_ocr_module"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "777"
    }
  }

  posix_user {
    gid = 1000
    uid = 1000
  }

  tags = {
    Name = "ap.lambda-ocr-module"
  }
}

