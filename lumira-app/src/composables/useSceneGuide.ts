import { SCENES, type SceneDef } from '@/data/scenes'

export function useSceneGuide() {
  const scenes: SceneDef[] = SCENES

  function filterByScene(sceneKey: string): string {
    const scene = scenes.find((s) => s.key === sceneKey)
    return scene?.category ?? ''
  }

  return { scenes, filterByScene }
}
