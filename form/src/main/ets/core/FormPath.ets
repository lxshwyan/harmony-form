/** Reads one dot-separated field path from a nested form model. */
export function getFormValue(values: Record<string, Object>, path: string): Object | undefined {
  const segments = formPathSegments(path);
  let current: Object | undefined = values;
  for (const segment of segments) {
    if (!isFormRecord(current)) return undefined;
    current = (current as Record<string, Object>)[segment];
  }
  return copyFormValue(current);
}

/** Returns a new nested form model with one path replaced or removed. */
export function setFormValue(values: Record<string, Object>, path: string,
  value: Object | undefined): Record<string, Object> {
  return updateFormRecord(values, formPathSegments(path), 0, value);
}

/** Internal/publicly declaration-safe deep snapshot for JSON-like form values. */
export function copyFormValues(values: Record<string, Object>): Record<string, Object> {
  const result: Record<string, Object> = {};
  for (const key of Object.keys(values)) {
    const value = copyFormValue(values[key]);
    if (value !== undefined) result[key] = value;
  }
  return result;
}

export function formValuesEqual(left: Record<string, Object>, right: Record<string, Object>): boolean {
  return formValueEqual(left, right);
}

export function validateFormPath(path: string): void {
  formPathSegments(path);
}

export function formPathConflicts(left: string, right: string): boolean {
  return left !== right && (left.startsWith(`${right}.`) || right.startsWith(`${left}.`));
}

function formPathSegments(path: string): string[] {
  if (path.trim() !== path || path === '' || path.includes('[') || path.includes(']')) {
    throw new Error(`Invalid form field path: ${path}`);
  }
  const segments = path.split('.');
  const forbidden = ['__proto__', 'prototype', 'constructor'];
  for (const segment of segments) {
    if (segment === '' || segment.trim() !== segment || /^\d+$/.test(segment) || forbidden.includes(segment)) {
      throw new Error(`Invalid form field path: ${path}`);
    }
  }
  return segments;
}

function updateFormRecord(source: Record<string, Object>, segments: string[], index: number,
  value: Object | undefined): Record<string, Object> {
  const result: Record<string, Object> = {};
  const key = segments[index];
  for (const sourceKey of Object.keys(source)) {
    if (sourceKey !== key) {
      const copied = copyFormValue(source[sourceKey]);
      if (copied !== undefined) result[sourceKey] = copied;
    }
  }
  if (index === segments.length - 1) {
    const copied = copyFormValue(value);
    if (copied !== undefined) result[key] = copied;
    return result;
  }
  const existing = source[key];
  const childSource: Record<string, Object> = isFormRecord(existing)
    ? existing as Record<string, Object>
    : {};
  const child = updateFormRecord(childSource, segments, index + 1, value);
  if (Object.keys(child).length > 0) result[key] = child;
  return result;
}

export function copyFormValue(value: Object | undefined): Object | undefined {
  if (value === undefined) return undefined;
  if (value instanceof Date) return new Date((value as Date).getTime());
  if (Array.isArray(value)) {
    const result: Array<Object> = [];
    for (const item of value as Array<Object>) {
      const copied = copyFormValue(item);
      if (copied !== undefined) result.push(copied);
    }
    return result;
  }
  if (isFormRecord(value)) return copyFormValues(value as Record<string, Object>);
  return value;
}

export function formValueEqual(left: Object | undefined, right: Object | undefined): boolean {
  if (left === right) return true;
  if (left === undefined || right === undefined) return false;
  if (left instanceof Date || right instanceof Date) {
    return left instanceof Date && right instanceof Date &&
      (left as Date).getTime() === (right as Date).getTime();
  }
  if (Array.isArray(left) || Array.isArray(right)) {
    if (!Array.isArray(left) || !Array.isArray(right)) return false;
    const leftArray = left as Array<Object>;
    const rightArray = right as Array<Object>;
    if (leftArray.length !== rightArray.length) return false;
    for (let index = 0; index < leftArray.length; index++) {
      if (!formValueEqual(leftArray[index], rightArray[index])) return false;
    }
    return true;
  }
  if (isFormRecord(left) || isFormRecord(right)) {
    if (!isFormRecord(left) || !isFormRecord(right)) return false;
    const leftRecord = left as Record<string, Object>;
    const rightRecord = right as Record<string, Object>;
    const leftKeys = Object.keys(leftRecord);
    const rightKeys = Object.keys(rightRecord);
    if (leftKeys.length !== rightKeys.length) return false;
    for (const key of leftKeys) {
      if (rightRecord[key] === undefined || !formValueEqual(leftRecord[key], rightRecord[key])) return false;
    }
    return true;
  }
  return false;
}

function isFormRecord(value: Object | undefined): boolean {
  return value !== undefined && value !== null && typeof value === 'object' &&
    !Array.isArray(value) && !(value instanceof Date);
}
