import { Resend } from 'resend';
import { ORPCError } from '@orpc/server';

export async function sendOtpEmail(apiKey: string, email: string, otp: number): Promise<void> {
  const resend = new Resend(apiKey);

  try {
    await resend.emails.send({
      from: 'FASQ <onboarding@resend.dev>',
      to: email,
      subject: 'Your OTP Code',
      html: `
        <div style="font-family: Arial, sans-serif; padding: 20px;">
          <h2>Your OTP Code</h2>
          <p>Your one-time password is:</p>
          <h1 style="color: #4CAF50; font-size: 32px; letter-spacing: 5px;">${otp}</h1>
          <p>This code will expire in 5 minutes.</p>
          <p>If you didn't request this code, please ignore this email.</p>
        </div>
      `,
    });
  } catch (error) {
    console.error('Failed to send OTP email:', error);
    throw new ORPCError('INTERNAL_SERVER_ERROR', {
      message: 'Failed to send OTP email',
    });
  }
}

