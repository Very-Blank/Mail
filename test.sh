(
  sleep 1; printf 'HELO localhost\r\n'
  sleep 1; printf 'MAIL FROM:<sender@example.com>\r\n'
  sleep 1; printf 'RCPT TO:<recipient@example.com>\r\n'
  sleep 1; printf 'DATA\r\n'
  sleep 1; printf 'Subject: Test message\r\nFrom: sender@example.com\r\nTo: recipient@example.com\r\n\r\nHello, this is a test.\r\n.\r\n'
  sleep 1; printf 'QUIT\r\n'
) | nc 127.0.0.1 6000
