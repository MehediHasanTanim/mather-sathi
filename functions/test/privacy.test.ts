import { HttpsError } from "firebase-functions/v2/https";
import { eraseUser, type Eraser } from "../src/deleteMyData";
import { handleBackupDeleted, parseBackupPath } from "../src/backupPhoto";

function fakeEraser(fail: string[] = []) {
  const calls: string[] = [];
  const step = (name: string, ret?: number) => async (uid: string) => {
    calls.push(`${name}:${uid}`);
    if (fail.includes(name)) throw new Error(`${name} down`);
    return ret as never;
  };
  const e: Eraser = { history: step("history"), reports: step("reports", 3), backups: step("backups"), contrib: step("contrib") };
  return { e, calls };
}

describe("eraseUser (deleteMyData)", () => {
  beforeEach(() => jest.spyOn(console, "error").mockImplementation(() => {}));
  afterEach(() => jest.restoreAllMocks());

  it("deletes history, reports, backups and contributions for exactly the caller", async () => {
    const { e, calls } = fakeEraser();
    expect(await eraseUser("u1", e)).toEqual({ reports: 3 });
    expect(calls).toEqual(["history:u1", "reports:u1", "backups:u1", "contrib:u1"]);
  });

  it("rejects an unauthenticated call before touching anything", async () => {
    const { e, calls } = fakeEraser();
    for (const bad of [undefined, null, "", 5]) {
      await expect(eraseUser(bad, e)).rejects.toMatchObject({ code: "unauthenticated" });
    }
    expect(calls).toEqual([]);
  });

  it("a failing step does not stop the others, and the call fails so the app never claims success", async () => {
    const { e, calls } = fakeEraser(["reports"]);
    await expect(eraseUser("u1", e)).rejects.toMatchObject({ code: "internal", message: expect.stringContaining("reports") });
    expect(calls).toEqual(["history:u1", "reports:u1", "backups:u1", "contrib:u1"]);
  });

  it("reports every failed step", async () => {
    const { e } = fakeEraser(["backups", "contrib"]);
    const err = (await eraseUser("u1", e).catch((x) => x)) as HttpsError;
    expect(err.message).toBe("delete incomplete: backups,contrib");
  });
});

describe("onBackupDeleted", () => {
  it("parses only backups/{uid}/{id}.jpg", () => {
    expect(parseBackupPath("backups/u1/abc.jpg")).toEqual({ uid: "u1", id: "abc" });
    for (const n of ["contrib/u1/abc.jpg", "backups/u1/abc.png", "backups/u1/x/abc.jpg", "backups/abc.jpg", "kb/index.json"]) {
      expect(parseBackupPath(n)).toBeNull();
    }
  });

  it("clears photoUrl of the matching history doc and ignores other objects", async () => {
    const cleared: string[] = [];
    const docs = { clearPhotoUrl: async (u: string, i: string) => void cleared.push(`${u}/${i}`) };
    expect(await handleBackupDeleted("backups/u1/h1.jpg", docs)).toBe(true);
    expect(await handleBackupDeleted("contrib/u1/h1.jpg", docs)).toBe(false);
    expect(cleared).toEqual(["u1/h1"]);
  });
});
