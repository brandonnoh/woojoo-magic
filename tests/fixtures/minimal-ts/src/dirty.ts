export function bad(x: any): any {
  const result = x!.value;
  try { JSON.parse("{}"); } catch (e) {}
  return result;
}
