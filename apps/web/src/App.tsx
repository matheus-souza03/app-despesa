import { useEffect, useState } from 'react';

type SituacaoApi = 'verificando' | 'no ar' | 'fora do ar';

export function App() {
  const [api, setApi] = useState<SituacaoApi>('verificando');

  useEffect(() => {
    fetch('/api/saude')
      .then((resposta) => setApi(resposta.ok ? 'no ar' : 'fora do ar'))
      .catch(() => setApi('fora do ar'));
  }, []);

  return (
    <div className="min-h-dvh">
      <header className="flex h-16 items-center gap-3 bg-primaria px-5 text-white">
        <img src="/logo-senco-96.png" alt="" className="size-8" />
        <span className="text-[22px] font-semibold">Despesas</span>
      </header>
      <main className="mx-auto max-w-xl px-5 py-8">
        <h1 className="text-[22px] font-semibold text-primaria">Esqueleto do app</h1>
        <p className="mt-2 text-texto-suave">
          As telas entram nas etapas 6 a 10 do README, seguindo docs/telas e o design system.
        </p>
        <p role="status" className="mt-6 rounded-cartao border border-borda bg-superficie p-4">
          API: <strong>{api}</strong>
        </p>
      </main>
    </div>
  );
}
