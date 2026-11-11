export function Unavailable({ feature }: { feature: string }) {
  return <div className="pd-card" role="status">
    <h3 className="pd-sub">{feature}暂未接入</h3>
    <p>当前版本后端尚未提供对应管理接口，真实模式下不显示模拟数据，也不开放提交入口。</p>
    <p className="pd-hint">需要预览界面时，请退出登录并在登录页选择演示模式。演示结果不代表后端已保存。</p>
  </div>;
}
