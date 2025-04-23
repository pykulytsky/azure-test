import { Injectable } from '@nestjs/common';

@Injectable()
export class AppService {
  getHello(): string {
    return `Hello World! From nestjs. Db Url: ${process.env.APPSETTING_DB_URL}`;
  }
}
