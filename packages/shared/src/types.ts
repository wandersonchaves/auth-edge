export interface UserContext {
  sub: string;
  email: string;
  groups: string[];
}

export interface AuthorizerContext {
  userId: string;
  email: string;
  groups: string; // AWS Gateway authorizer context likes strings
}
