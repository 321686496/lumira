import { IsEmail, IsIn } from 'class-validator';
export class SendCodeDto {
  @IsEmail()
  email!: string;
  @IsIn(['bind', 'recover'])
  purpose!: 'bind' | 'recover';
}