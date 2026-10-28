import { appTasks, OhosAppContext, OhosPluginId } from '@ohos/hvigor-ohos-plugin';
import { getNode } from '@ohos/hvigor';
import { existsSync, readFileSync } from 'fs';
import { resolve } from 'path';

const LOCAL_SIGNING_PATH = resolve(__dirname, 'signing', 'signing.local.json');
const rootNode = getNode(__filename);

rootNode.afterNodeEvaluate((node) => {
  if (!existsSync(LOCAL_SIGNING_PATH)) {
    return;
  }

  const local = JSON.parse(readFileSync(LOCAL_SIGNING_PATH, 'utf8')) as {
    signingConfig: object;
  };
  const appContext = node.getContext(OhosPluginId.OHOS_APP_PLUGIN) as OhosAppContext;
  const profile = appContext.getBuildProfileOpt();
  profile['app']['signingConfigs'] = [local.signingConfig];
  appContext.setBuildProfileOpt(profile);
});

export default {
  system: appTasks, /* Built-in plugin of Hvigor. It cannot be modified. */
  plugins: []       /* Custom plugin to extend the functionality of Hvigor. */
}
